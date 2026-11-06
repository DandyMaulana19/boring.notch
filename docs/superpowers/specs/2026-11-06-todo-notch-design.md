# Todo List in the Notch — Design

Date: 2026-11-06
Branch: `feat/todo-notch`

## Goal

Add a simple todo list to Boring Notch. The user manages todos in a dedicated
tab of the open notch. While at least one todo is unfinished and no music is
playing, the closed notch shows how many todos are still unchecked, and
that number pulses gently.

Example: 5 todos, numbers 1–3 checked → the closed notch shows **2**.
While music is playing the number is hidden and the notch border pulses
instead (toggle: Settings → General → Todo).

## Scope

In scope:
- Todo data model, persistence and ordering logic
- New "Todo" tab next to Home and Shelf in the existing header tab bar
- Add, check/uncheck, delete and drag-to-reorder todos
- Closed-notch indicator: checklist icon + pulsing number

Out of scope (possible later work):
- Deadlines / due dates
- Sync with Apple Reminders
- A new tab bar style (the existing header tab bar is kept as is)

## 1. Data and logic

### `boringNotch/models/TodoItem.swift` (new)

```swift
struct TodoItem: Codable, Identifiable, Equatable, Defaults.Serializable {
    let id: UUID
    var title: String
    var isDone: Bool
    let createdAt: Date
}
```

### `boringNotch/managers/TodoManager.swift` (new)

`@MainActor final class TodoManager: ObservableObject`, singleton `shared`.

- `@Published private(set) var items: [TodoItem]`, loaded from
  `Defaults[.todoItems]` on init and written back on every change.
- `add(_ title: String)` — trims whitespace; ignores empty titles; appends to
  the end of the list.
- `toggle(_ id: UUID)` — flips `isDone`.
- `delete(_ id: UUID)` — removes the item.
- `move(fromOffsets: IndexSet, toOffset: Int)` — reorders (used by drag).
- `pendingCount: Int` — number of items with `isDone == false`.
  (Revised 2026-11-06: originally `nextPendingNumber`, the position of the
  first unfinished todo; changed at the user's request to the count.)

Numbering rule: a todo's number is always its current position in the list
(1-based). Checked todos stay in the list and keep their position. Deleting or
moving a todo renumbers the items after it. Numbers are never stored.

### `boringNotch/models/Constants.swift` (edit)

Add a Defaults key:

```swift
static let todoItems = Key<[TodoItem]>("todoItems", default: [])
```

## 2. Todo tab (open notch)

### Tab registration (edits)

- `boringNotch/enums/generic.swift`: add `case todo` to `NotchViews`.
- `boringNotch/components/Tabs/TabSelectionView.swift`: add
  `TabModel(label: "Todo", icon: "checklist", view: .todo)` after Shelf.
- `boringNotch/ContentView.swift`: add `case .todo: TodoView()` to the
  `switch coordinator.currentView` (around line 347).

The header tab bar itself is unchanged. Todo is its own tab; nothing is added
to the Home view.

### `boringNotch/components/Todo/TodoView.swift` (new)

Layout, top to bottom, sized to fit the existing open-notch content area:

1. **Input row** — a `TextField` with placeholder "Add a todo…". Return adds
   the todo and clears the field. When the field gains focus the view calls
   `SharingStateManager.shared.beginInteraction()` so the notch does not
   auto-close while typing; it calls `endInteraction()` exactly once when
   focus is lost or the view disappears (guarded by a local flag so begin/end
   stay balanced).
2. **List** — scrollable. Each row shows:
   - its number (`1.`, `2.`, …), secondary color;
   - a checkbox button (`circle` / `checkmark.circle.fill`) that toggles done;
   - the title, struck through and dimmed when done;
   - a delete button (`xmark`) visible only while the row is hovered;
   - a drag handle (`line.3.horizontal`); rows are reorderable by drag via
     `onMove`, which calls `TodoManager.move`.
3. **Empty state** — when there are no todos, show
   `EmptyStateView(message: "No todos yet")` (existing component in
   `components/EmptyState.swift`) below the input row.

## 3. Closed notch indicator

### `boringNotch/components/Todo/TodoLiveActivity.swift` (new)

A `View` struct following the same layout pattern as the
`MusicLiveActivity()` function in `ContentView.swift`: an `HStack` of
`[left content] [black spacer of closedNotchSize.width] [right content]`,
height `vm.effectiveClosedNotchHeight`.

- Left: `checklist` SF Symbol, white, small.
- Right: `pendingCount` (shown only when > 0), white, semibold, monospaced
  digits. It pulses continuously: opacity 1.0 ↔ 0.45 and scale 1.0 ↔ 1.12,
  ~1.2 s ease-in-out, repeating forever while visible.

### Placement in `ContentView.swift` (edit)

Insert a new branch into the closed-notch `if / else if` chain (around line
290), **after** the music live activity branch and **before** the
`BoringFaceAnimation` branch:

```
else if !coordinator.expandingView.show
     && vm.notchState == .closed
     && (!musicManager.isPlaying && musicManager.isPlayerIdle)
     && todoManager.pendingCount > 0
     && !vm.hideOnClosed {
    TodoLiveActivity()
}
```

`ContentView` gains `@ObservedObject var todoManager = TodoManager.shared`
next to the other managers so the view updates when todos change.

Resulting behavior:

| State | Closed notch shows |
|---|---|
| Music playing / player not idle | Music live activity (unchanged) |
| No music, ≥1 unfinished todo | Checklist icon + pulsing number |
| No music, no unfinished todos | Previous behavior (face / empty) |
| Battery or HUD notification | Notification (unchanged, higher priority) |

The chin-width computation near the top of `ContentView` (lines 62–73) gets a
matching case so the closed notch widens for the todo indicator the same way
it does for the music live activity.

## 4. Error handling and edge cases

- Empty or whitespace-only titles are ignored.
- Defaults decoding failure falls back to the key default (`[]`) — handled by
  the Defaults library.
- Deleting the todo currently shown in the closed notch updates the number
  immediately (it is derived, not stored).
- Very long titles are truncated to one line with an ellipsis in the list.

## 5. Testing

The project has no unit-test target, and adding one is out of scope. So:

- `pendingCount` is kept a small pure computation on `items` so it is
  easy to verify by reading.
- Build with `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch build`.
- Manual check in the running app:
  1. Add 5 todos; check 1–3; close the notch → "4" pulses.
  2. Drag todo 5 to the top → closed notch shows "1".
  3. Check every todo → indicator disappears, face/empty returns.
  4. Play music with unfinished todos → music activity shows, no todo number;
     pause until idle → todo number returns.
  5. Type in the input with the cursor outside the notch → notch stays open.
  6. Quit and relaunch → todos and their order persist.
