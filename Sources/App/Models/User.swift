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
    static let spendingLimitKey = "spendingLimit"
    static let sTokenKey = "sToken"

    let storage = Storage()

    let name: String
    let payday: Int
    let endOfMonthBalance: Double
    var sToken: String?

    var token: Children<User, Token> {
        return children()
    }

    var transactions: Children<User, Transaction> {
        return children()
    }

    var spendingLimit: Double {
        guard let transactions = try? self.transactions.all() else { return 0 }
        let sum = transactions.flatMap({ $0.amount }).reduce(0, +)
        return sum
    }

    init(name: String,
         payday: Int,
         endOfMonthBalance: Double,
         sToken: String?) {
        self.name = name
        self.payday = payday
        self.endOfMonthBalance = endOfMonthBalance
        self.sToken = sToken
    }

    init(row: Row) throws {
        name = try row.get(User.nameKey)
        payday = try row.get(User.paydayKey)
        endOfMonthBalance = try row.get(User.endOfMonthBalanceKey)
        sToken = try row.get(User.sTokenKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(User.nameKey, name)
        try row.set(User.paydayKey, payday)
        try row.set(User.endOfMonthBalanceKey, endOfMonthBalance)
        try row.set(User.sTokenKey, sToken)
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
            builder.double(User.sTokenKey, optional: true, unique: false, default: nil)
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
                      endOfMonthBalance: json.get(User.endOfMonthBalanceKey),
                      sToken: nil)
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(User.idKey, id)
        let tokenString = try token.first()?.token
        try json.set(User.tokenKey, tokenString)
        try json.set(User.nameKey, name)
        try json.set(User.paydayKey, payday)
        try json.set(User.endOfMonthBalanceKey, endOfMonthBalance)
        try json.set(User.spendingLimitKey, spendingLimit)
        return json
    }

}

extension User: ResponseRepresentable {}

extension User: TokenAuthenticatable {

    public typealias TokenType = Token

}
