//
//  Token.swift
//  App
//
//  Created by Attila Nemet on 22/01/2018.
//

import Vapor
import FluentProvider
import Crypto

final class Token: Model {

    static let idKey = "id"
    static let tokenKey = "token"
    static let userIdKey = "userId"

    let storage = Storage()

    let token: String
    let userId: Identifier?

    var user: Parent<Token, User> {
        return parent(id: userId)
    }

    init(token: String,
         user: User) {
        self.token = token
        self.userId = user.id
    }

    init(row: Row) throws {
        token = try row.get(Token.tokenKey)
        userId = try row.get(User.foreignIdKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Token.tokenKey, token)
        try row.set(User.foreignIdKey, userId)
        return row
    }

}

extension Token: Preparation {

    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Token.tokenKey)
            builder.parent(User.self)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete(self)
    }

}

extension Token: JSONConvertible {

    convenience init(json: JSON) throws {
        let userId: Identifier = try json.get(Token.userIdKey)
        guard let user = try User.find(userId) else { throw Abort.badRequest }
        try self.init(token: json.get(Token.tokenKey),
                      user: user)
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Token.tokenKey, token)
        return json
    }

}

extension Token: ResponseRepresentable {}

extension Token {

    static func generate(for user: User) throws -> Token {
        let random = try Crypto.Random.bytes(count: 48)
        return Token(token: random.base64Encoded.makeString(), user: user)
    }

}
