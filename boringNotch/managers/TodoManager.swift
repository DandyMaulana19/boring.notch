//
//  TodoManager.swift
//  boringNotch
//

import Defaults
import Foundation
import SwiftUI

/// Owns the todo list and persists it to `Defaults[.todoItems]`.
/// A todo's list number is its 1-based position in `items`.
@MainActor
final class TodoManager: ObservableObject {
    static let shared = TodoManager()

    @Published private(set) var items: [TodoItem] {
        didSet { Defaults[.todoItems] = items }
    }

    /// Number of todos not yet checked; shown in the closed notch.
    var pendingCount: Int {
        items.filter { !$0.isDone }.count
    }

    private init() {
        items = Defaults[.todoItems]
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(title: trimmed))
    }

    func toggle(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isDone.toggle()
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }
}
