//
//  User.swift
//  App
//
//  Created by Attila Nemet on 15/10/2017.
//

import Vapor
import FluentProvider
import AuthProvider

final class User: Model {

    static let idKey = "id"
    static let tokenKey = "token"
    static let nameKey = "name"
    static let paydayKey = "payday"
    static let endOfMonthBalanceKey = "endOfMonthBalance"

    let storage = Storage()

    let name: String
    let payday: Int
    let endOfMonthBalance: Double

    var token: Children<User, Token> {
        return children()
    }

    var transactions: Children<User, Transaction> {
        return children()
    }

    init(name: String,
         payday: Int,
         endOfMonthBalance: Double) {
        self.name = name
        self.payday = payday
        self.endOfMonthBalance = endOfMonthBalance
    }

    init(row: Row) throws {
        name = try row.get(User.nameKey)
        payday = try row.get(User.paydayKey)
        endOfMonthBalance = try row.get(User.endOfMonthBalanceKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(User.nameKey, name)
        try row.set(User.paydayKey, payday)
        try row.set(User.endOfMonthBalanceKey, endOfMonthBalance)
        return row
    }

}

extension User: Preparation {

    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(User.nameKey)
            builder.int(User.paydayKey)
            builder.double(User.endOfMonthBalanceKey)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete(self)
    }

}

extension User: JSONConvertible {

    convenience init(json: JSON) throws {
        try self.init(name: json.get(User.nameKey),
                      payday: json.get(User.paydayKey),
                      endOfMonthBalance: json.get(User.endOfMonthBalanceKey))
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(User.idKey, id)
        let tokenString = try token.first()?.token
        try json.set(User.tokenKey, tokenString)
        try json.set(User.nameKey, name)
        try json.set(User.paydayKey, payday)
        try json.set(User.endOfMonthBalanceKey, endOfMonthBalance)
        return json
    }

}

extension User: ResponseRepresentable {}

extension User: TokenAuthenticatable {

    public typealias TokenType = Token

}
