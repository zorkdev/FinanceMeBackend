//
//  User.swift
//  App
//
//  Created by Attila Nemet on 15/10/2017.
//

import Vapor
import FluentProvider

final class User: Model {

    static let idKey = "id"
    static let nameKey = "name"

    let storage = Storage()

    let name: String

    var reminders: Children<User, Reminder> {
        return children()
    }

    init(name: String) {
        self.name = name
    }

    init(row: Row) throws {
        name = try row.get(User.nameKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(User.nameKey, name)
        return row
    }

}

extension User: Preparation {

    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(User.nameKey)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete(self)
    }

}

extension User: JSONConvertible {

    convenience init(json: JSON) throws {
        try self.init(name: json.get(User.nameKey))
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(User.idKey, id)
        try json.set(User.nameKey, name)
        return json
    }

}

extension User: ResponseRepresentable {}
