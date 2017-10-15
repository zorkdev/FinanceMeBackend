//
//  Category.swift
//  App
//
//  Created by Attila Nemet on 15/10/2017.
//

import Vapor
import FluentProvider

final class Category: Model {

    static let entity = "categories"

    static let idKey = "id"
    static let nameKey = "name"

    let storage = Storage()

    let name: String

    var reminders: Siblings<Category, Reminder, Pivot<Category, Reminder>> {
        return siblings()
    }

    init(name: String) {
        self.name = name
    }

    init(row: Row) throws {
        name = try row.get(Category.nameKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Category.nameKey, name)
        return row
    }

}

extension Category: Preparation {

    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Category.nameKey)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete(self)
    }

}

extension Category: JSONConvertible {

    convenience init(json: JSON) throws {
        try self.init(name: json.get(Category.nameKey))
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Category.idKey, id)
        try json.set(Category.nameKey, name)
        return json
    }

}

extension Category: ResponseRepresentable {}
