//
//  TodoManager.swift
//  boringNotch
//

import Defaults
import Foundation
import SwiftUI

/// Owns the todo list and persists it to `Defaults[.todoItems]`.
/// A todo's number is always its 1-based position in `items`.
@MainActor
final class TodoManager: ObservableObject {
    static let shared = TodoManager()

    @Published private(set) var items: [TodoItem] {
        didSet { Defaults[.todoItems] = items }
    }

    /// 1-based position of the first unfinished todo, or `nil` if none.
    var nextPendingNumber: Int? {
        items.firstIndex(where: { !$0.isDone }).map { $0 + 1 }
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
