//
//  TodoItem.swift
//  boringNotch
//

import Defaults
import Foundation

struct TodoItem: Codable, Identifiable, Equatable, Defaults.Serializable {
    let id: UUID
    var title: String
    var isDone: Bool
    let createdAt: Date

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isDone = false
        self.createdAt = Date()
    }
}
