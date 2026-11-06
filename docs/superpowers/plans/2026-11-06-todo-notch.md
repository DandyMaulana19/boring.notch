# Todo List in the Notch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Todo tab in the open notch, and a pulsing "next unfinished todo" number in the closed notch when no music is playing.

**Architecture:** A `TodoManager` singleton (ObservableObject) owns `[TodoItem]`, persisted through the existing `Defaults` library. `TodoView` is a new tab registered in the existing header tab bar. `TodoLiveActivity` is a new branch in `ContentView`'s closed-notch `if/else` chain, placed after music and before the face animation.

**Tech Stack:** Swift, SwiftUI, macOS, `Defaults` (sindresorhus), Xcode project with file-system-synchronized groups (new files under `boringNotch/` are picked up automatically — no `.pbxproj` edits).

**Spec:** `docs/superpowers/specs/2026-11-06-todo-notch-design.md`

## Global Constraints

- Work on branch `feat/todo-notch`.
- No new dependencies. Persistence uses `Defaults` key `todoItems`, default `[]`.
- The header tab bar is unchanged except for one new entry: `TabModel(label: "Todo", icon: "checklist", view: .todo)` after Shelf.
- A todo's number = its 1-based position in the list; numbers are never stored.
- Closed-notch indicator shows only when no music is playing and the player is idle (`!musicManager.isPlaying && musicManager.isPlayerIdle`).
- Pulse: opacity 1.0 ↔ 0.45, scale 1.0 ↔ 1.12, ~1.2 s ease-in-out, repeating forever.
- There is no unit-test target; adding one is out of scope. Each task's gate is a clean build plus the listed manual checks.

**Build command (used by every task):**

```bash
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|warning: .*Todo|BUILD (SUCCEEDED|FAILED)"
```

Expected: `** BUILD SUCCEEDED **` and no `error:` lines. (If the scheme name differs, use the one shown by `xcodebuild -list`.)

## Review Focus

1. **Notch auto-close while typing** — clicking into the input then moving the cursor out of the notch must not close it; leaving the tab or closing the notch must not leave `beginInteraction()` unbalanced (notch stuck open forever). Owned by Task 2, manual check 2c.
2. **Todo number while music is paused but player not idle** — must show music, not the todo number, matching the existing music/face conditions. Owned by Task 3, manual check 3c.
3. **Closed-notch width** — the indicator must not clip into the physical notch; chin width must widen exactly like the face case. Owned by Task 3, manual check 3a.
4. **Persistence and order across relaunch** — reorder, quit, relaunch: order and done-state survive. Owned by Task 1/2, manual check 2d.
5. **Whitespace-only / empty input** — Return with empty or spaces-only text adds nothing. Owned by Task 2, manual check 2a.

---

### Task 1: Todo data model and manager

**Files:**
- Create: `boringNotch/models/TodoItem.swift`
- Create: `boringNotch/managers/TodoManager.swift`
- Modify: `boringNotch/models/Constants.swift` (add key next to the other `static let … = Key<…>` lines, ~line 73–95)

**Interfaces:**
- Produces:
  - `struct TodoItem: Codable, Identifiable, Equatable, Defaults.Serializable { let id: UUID; var title: String; var isDone: Bool; let createdAt: Date }` with `init(title: String)` setting `id = UUID()`, `isDone = false`, `createdAt = Date()`.
  - `extension Defaults.Keys { static let todoItems = Key<[TodoItem]>("todoItems", default: []) }`
  - `@MainActor final class TodoManager: ObservableObject`
    - `static let shared: TodoManager`
    - `@Published private(set) var items: [TodoItem]`
    - `func add(_ title: String)`
    - `func toggle(_ id: UUID)`
    - `func delete(_ id: UUID)`
    - `func move(fromOffsets source: IndexSet, toOffset destination: Int)`
    - `var nextPendingNumber: Int? { get }`

- [ ] **Step 1: Create `TodoItem.swift`** with the struct above (`import Foundation`, `import Defaults`).

- [ ] **Step 2: Add the `todoItems` key** in `Constants.swift`.

- [ ] **Step 3: Create `TodoManager.swift`.**
  - `private init()` loads `items = Defaults[.todoItems]`.
  - Every mutating method changes `items`, then writes `Defaults[.todoItems] = items` (a `didSet` on a private backing store or a `private func save()` — implementer's choice).
  - `add`: trim with `.whitespacesAndNewlines`; return without change if empty; append `TodoItem(title:)`.
  - `move`: `items.move(fromOffsets:toOffset:)`.
  - `nextPendingNumber`: `items.firstIndex(where: { !$0.isDone }).map { $0 + 1 }`.

- [ ] **Step 4: Build** with the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add boringNotch/models/TodoItem.swift boringNotch/managers/TodoManager.swift boringNotch/models/Constants.swift
git commit -m "feat(todo): add TodoItem model and TodoManager persistence"
```

---

### Task 2: Todo tab in the open notch

**Files:**
- Create: `boringNotch/components/Todo/TodoView.swift`
- Modify: `boringNotch/enums/generic.swift:27-30` (add `case todo`)
- Modify: `boringNotch/components/Tabs/TabSelectionView.swift:17-20` (add tab entry)
- Modify: `boringNotch/ContentView.swift:347-352` (add `case .todo: TodoView()`)

**Interfaces:**
- Consumes: `TodoManager.shared` and its methods/properties from Task 1; `SharingStateManager.shared.beginInteraction()` / `endInteraction()`; `EmptyStateView(message: String)`.
- Produces: `struct TodoView: View` (no init parameters); `NotchViews.todo`.

- [ ] **Step 1: Register the tab.** Add `case todo` to `NotchViews`; add `TabModel(label: "Todo", icon: "checklist", view: .todo)` after Shelf; add `case .todo: TodoView()` to the `switch coordinator.currentView` in `ContentView`.

- [ ] **Step 2: Create `TodoView.swift`.** `@ObservedObject var manager = TodoManager.shared`. Layout (`VStack`, fills the open-notch content area):
  - **Input row:** `TextField("Add a todo…", text: $draft)` with `.onSubmit { manager.add(draft); draft = "" }`, `@FocusState` for focus, plain rounded style matching the dark notch.
  - **Close prevention:** `@State private var holdingNotch = false`. On focus gained and `!holdingNotch` → `beginInteraction()`, `holdingNotch = true`. On focus lost or `.onDisappear`, if `holdingNotch` → `endInteraction()`, `holdingNotch = false`. Begin/end must stay balanced.
  - **Empty state:** when `manager.items.isEmpty`, show `EmptyStateView(message: "No todos yet")`.
  - **List:** `List { ForEach(Array(manager.items.enumerated()), id: \.element.id) { … }.onMove(perform: manager.move) }` with `.scrollContentBackground(.hidden)` and clear row backgrounds. Each row (`HStack`):
    - `Text("\(index + 1).")`, secondary color, monospaced digits;
    - checkbox `Button` with `circle` / `checkmark.circle.fill`, calls `manager.toggle(item.id)`;
    - `Text(item.title)`, `.lineLimit(1)`, `.strikethrough(item.isDone)`, dimmed when done;
    - `Spacer()`;
    - `xmark` delete `Button` shown only while the row is hovered (`@State` hovered id + `.onHover`), calls `manager.delete(item.id)`;
    - `Image(systemName: "line.3.horizontal")` drag handle, secondary color.

- [ ] **Step 3: Build.** Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manual checks** (run the app from Xcode or the built product):
  - 2a. Open notch → Todo tab is visible after Shelf. Return on empty and spaces-only input adds nothing.
  - 2b. Add 3 todos → numbered 1–3; check #2 → struck through, still numbered 2; hover → delete appears; delete #1 → remaining renumber to 1–2; drag a row → numbers follow the new order.
  - 2c. Click in the input, move the cursor out of the notch → notch stays open. Click elsewhere / switch to Home → notch closes normally again on mouse-out.
  - 2d. Reorder and check some items, quit, relaunch → same items, order and done state.

- [ ] **Step 5: Commit**

```bash
git add boringNotch/components/Todo/TodoView.swift boringNotch/enums/generic.swift boringNotch/components/Tabs/TabSelectionView.swift boringNotch/ContentView.swift
git commit -m "feat(todo): add Todo tab with add, check, delete and reorder"
```

---

### Task 3: Pulsing todo number in the closed notch

**Files:**
- Create: `boringNotch/components/Todo/TodoLiveActivity.swift`
- Modify: `boringNotch/ContentView.swift` — add manager property (~line 22–25), chin-width case (`computedChinWidth`, ~lines 62–80), closed-notch branch (~line 290–293)

**Interfaces:**
- Consumes: `TodoManager.shared.nextPendingNumber` (Task 1); `BoringViewModel` via `@EnvironmentObject var vm` (as other notch views use it): `vm.closedNotchSize`, `vm.effectiveClosedNotchHeight`.
- Produces: `struct TodoLiveActivity: View` (no init parameters).

- [ ] **Step 1: Create `TodoLiveActivity.swift`.** `HStack(spacing: 0)` of:
  - left: `Image(systemName: "checklist")`, white, in a frame of width `max(0, vm.effectiveClosedNotchHeight - 12) + 10`, centered;
  - middle: `Rectangle().fill(.black).frame(width: vm.closedNotchSize.width)`;
  - right: `Text("\(number)")`, white, `.font(.system(size: 13, weight: .semibold).monospacedDigit())`, same frame width as left, centered; pulse per Global Constraints driven by an `@State var pulsing` toggled in `.onAppear` with `.easeInOut(duration: 1.2).repeatForever(autoreverses: true)`.
  - whole view: `.frame(height: vm.effectiveClosedNotchHeight)`.
  - Render nothing if `nextPendingNumber` is `nil`.

- [ ] **Step 2: Wire into `ContentView`.**
  - Add `@ObservedObject var todoManager = TodoManager.shared` beside the other managers.
  - In the closed-notch chain, insert after the `MusicLiveActivity()` branch and before the `BoringFaceAnimation()` branch:
    `else if !coordinator.expandingView.show && vm.notchState == .closed && (!musicManager.isPlaying && musicManager.isPlayerIdle) && todoManager.nextPendingNumber != nil && !vm.hideOnClosed { TodoLiveActivity() }`
  - In `computedChinWidth`, insert the same condition as a new `else if` before the face case, adding `chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 20)`.

- [ ] **Step 3: Build.** Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manual checks:**
  - 3a. Add 5 todos, check 1–3, close the notch (no music) → checklist icon left, "4" right, pulsing; nothing clipped by the physical notch.
  - 3b. Drag todo 5 to the top → closed notch shows "1". Check all → indicator disappears, face/empty returns.
  - 3c. Play music → music activity shows, no todo number. Pause and wait until the player goes idle → todo number returns.
  - 3d. Trigger a volume/brightness HUD while the todo number shows → HUD takes priority, number returns afterwards.

- [ ] **Step 5: Commit**

```bash
git add boringNotch/components/Todo/TodoLiveActivity.swift boringNotch/ContentView.swift
git commit -m "feat(todo): show pulsing next-todo number in closed notch"
```
