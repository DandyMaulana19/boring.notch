//
//  TodoView.swift
//  boringNotch
//

import SwiftUI

struct TodoView: View {
    @ObservedObject var manager = TodoManager.shared
    @State private var draft = ""
    @State private var hoveredID: UUID?
    @State private var holdingNotch = false
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
        .onChange(of: inputFocused) { _, focused in
            focused ? holdNotchOpen() : releaseNotch()
        }
        .onDisappear { releaseNotch() }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.gray)
            TextField("Add a todo…", text: $draft)
                .textFieldStyle(.plain)
                .focused($inputFocused)
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

    // Keep the notch open while typing; begin/end must stay balanced.
    private func holdNotchOpen() {
        guard !holdingNotch else { return }
        SharingStateManager.shared.beginInteraction()
        holdingNotch = true
    }

    private func releaseNotch() {
        guard holdingNotch else { return }
        SharingStateManager.shared.endInteraction()
        holdingNotch = false
    }
}
