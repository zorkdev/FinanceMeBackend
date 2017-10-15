//
//  Reminder.swift
//  App
//
//  Created by Attila Nemet on 15/10/2017.
//

import Vapor
import FluentProvider

final class Reminder: Model {
    let storage = Storage()

    let title: String
    let description: String

    static let idKey = "id"
    static let titleKey = "title"
    static let descriptionKey = "description"

    init(title: String, description: String) {
        self.title = title
        self.description = description
    }

    init(row: Row) throws {
        self.title = try row.get(Reminder.titleKey)
        self.description = try row.get(Reminder.descriptionKey)
    }
    
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Reminder.titleKey, title)
        try row.set(Reminder.descriptionKey, description)
        return row
    }

}

extension Reminder: Preparation {

    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Reminder.titleKey)
            builder.string(Reminder.descriptionKey)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete(self)
    }

}

extension Reminder: JSONConvertible {

    convenience init(json: JSON) throws {
        try self.init(title: json.get(Reminder.titleKey), description: json.get(Reminder.descriptionKey))
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Reminder.idKey, id)
        try json.set(Reminder.titleKey, title)
        try json.set(Reminder.descriptionKey, description)
        return json
    }

}

extension Reminder: ResponseRepresentable {}
