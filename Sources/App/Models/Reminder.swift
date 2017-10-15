//
//  Reminder.swift
//  App
//
//  Created by Attila Nemet on 15/10/2017.
//

import Vapor
import FluentProvider

final class Reminder: Model {

    static let idKey = "id"
    static let titleKey = "title"
    static let descriptionKey = "description"
    static let userIDKey = "user_id"

    let storage = Storage()

    let title: String
    let description: String
    let userID: Identifier?

    var user: Parent<Reminder, User> {
        return parent(id: userID)
    }

    var categories: Siblings<Reminder, Category, Pivot<Reminder, Category>> {
        return siblings()
    }

    init(title: String, description: String, user: User) {
        self.title = title
        self.description = description
        userID = user.id
    }

    init(row: Row) throws {
        title = try row.get(Reminder.titleKey)
        description = try row.get(Reminder.descriptionKey)
        userID = try row.get(User.foreignIdKey)
    }
    
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Reminder.titleKey, title)
        try row.set(Reminder.descriptionKey, description)
        try row.set(User.foreignIdKey, userID)
        return row
    }

}

extension Reminder: Preparation {

    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Reminder.titleKey)
            builder.string(Reminder.descriptionKey)
            builder.parent(User.self)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete(self)
    }

}

extension Reminder: JSONConvertible {

    convenience init(json: JSON) throws {
        let userId: Identifier = try json.get("user_id")
        guard let user = try User.find(userId) else { throw Abort.badRequest }
        try self.init(title: json.get(Reminder.titleKey), description: json.get(Reminder.descriptionKey), user: user)
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Reminder.idKey, id)
        try json.set(Reminder.titleKey, title)
        try json.set(Reminder.descriptionKey, description)
        try json.set(Reminder.userIDKey, userID)
        return json
    }

}

extension Reminder: ResponseRepresentable {}
