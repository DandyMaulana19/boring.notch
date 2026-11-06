//
//  TodoView.swift
//  boringNotch
//

import SwiftUI

struct TodoView: View {
    @ObservedObject var manager = TodoManager.shared
    @State private var draft = ""
    @State private var hoveredID: UUID?
    @State private var hold = NotchOpenHold()
    @State private var hostWindow: NSWindow?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            inputRow
            if manager.items.isEmpty {
                Spacer(minLength: 0)
                EmptyStateView(message: "No todos yet")
                Spacer(minLength: 0)
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(HostingWindowReader { hostWindow = $0 })
        .onAppear { setKeyboardAccess(true) }
        .onDisappear {
            hold.end()
            setKeyboardAccess(false)
        }
        .onChange(of: hostWindow) { old, new in
            (old as? KeyboardAcceptingPanel)?.acceptsKeyboard = false
            setKeyboardAccess(true)
        }
        .onChange(of: inputFocused) { _, focused in
            focused ? hold.begin() : hold.end()
        }
        // Clicking another app (panel loses key) ends editing and lets the notch close.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            guard let window = note.object as? NSWindow, window === hostWindow else { return }
            inputFocused = false
            hold.end()
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.gray)
            TextField("Add a todo…", text: $draft)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .onExitCommand {
                    inputFocused = false
                    hold.end()
                }
                .onSubmit {
                    manager.add(draft)
                    draft = ""
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .secondarySystemFill))
        )
    }

    private var list: some View {
        List {
            ForEach(Array(manager.items.enumerated()), id: \.element.id) { index, item in
                row(index: index, item: item)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
            }
            .onMove(perform: manager.move)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(index: Int, item: TodoItem) -> some View {
        HStack(spacing: 8) {
            Text("\(index + 1).")
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(.gray)
                .frame(minWidth: 22, alignment: .trailing)

            Button {
                manager.toggle(item.id)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? Color.accentColor : .gray)
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? .gray : .white)

            Spacer(minLength: 4)

            if hoveredID == item.id {
                Button {
                    manager.delete(item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11))
                .foregroundStyle(.gray)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                hoveredID = item.id
            } else if hoveredID == item.id {
                hoveredID = nil
            }
        }
    }

    /// The notch panel may become key only while the Todo tab is shown,
    /// so clicking the input field gives it keyboard focus.
    private func setKeyboardAccess(_ enabled: Bool) {
        guard let panel = hostWindow as? KeyboardAcceptingPanel else { return }
        panel.acceptsKeyboard = enabled
        if !enabled, panel.isKeyWindow {
            panel.resignKey()
        }
    }
}
