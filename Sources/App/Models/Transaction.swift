//
//  Transaction.swift
//  zorkdev
//
//  Created by Attila Nemet on 22/01/2018.
//

import Vapor
import FluentProvider

final class Transaction: Model {

    static let idKey = "id"
    static let currencyKey = "currency"
    static let amountKey = "amount"
    static let directionKey = "direction"
    static let createdKey = "created"
    static let narrativeKey = "narrative"
    static let sourceKey = "source"
    static let balanceKey = "balance"

    let storage = Storage()

    let currency: String
    let amount: Double
    let direction: String
    let created: Date
    let narrative: String
    let source: String
    let balance: Double

    var userId: Identifier?

    var user: Parent<Transaction, User> {
        return parent(id: userId)
    }

    init(currency: String,
         amount: Double,
         direction: String,
         created: Date,
         narrative: String,
         source: String,
         balance: Double,
         user: User?
        ) {
        self.currency = currency
        self.amount = amount
        self.direction = direction
        self.created = created
        self.narrative = narrative
        self.source = source
        self.balance = balance
        self.userId = user?.id
    }

    init(row: Row) throws {
        currency = try row.get(Transaction.currencyKey)
        amount = try row.get(Transaction.amountKey)
        direction = try row.get(Transaction.directionKey)
        created = try row.get(Transaction.createdKey)
        narrative = try row.get(Transaction.narrativeKey)
        source = try row.get(Transaction.sourceKey)
        balance = try row.get(Transaction.balanceKey)
        userId = try row.get(User.foreignIdKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Transaction.currencyKey, currency)
        try row.set(Transaction.amountKey, amount)
        try row.set(Transaction.directionKey, direction)
        try row.set(Transaction.createdKey, created)
        try row.set(Transaction.narrativeKey, narrative)
        try row.set(Transaction.sourceKey, source)
        try row.set(Transaction.balanceKey, balance)
        try row.set(User.foreignIdKey, userId)
        return row
    }

}

extension Transaction: Preparation {

    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Transaction.currencyKey)
            builder.double(Transaction.amountKey)
            builder.string(Transaction.directionKey)
            builder.date(Transaction.createdKey)
            builder.string(Transaction.narrativeKey)
            builder.string(Transaction.sourceKey)
            builder.double(Transaction.balanceKey)
            builder.parent(User.self)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete(self)
    }

}

extension Transaction: JSONConvertible {

    convenience init(json: JSON) throws {
        try self.init(currency: json.get(Transaction.currencyKey),
                      amount: json.get(Transaction.amountKey),
                      direction: json.get(Transaction.directionKey),
                      created: json.get(Transaction.createdKey),
                      narrative: json.get(Transaction.narrativeKey),
                      source: json.get(Transaction.sourceKey),
                      balance: json.get(Transaction.balanceKey),
                      user: nil)
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Transaction.idKey, id)
        try json.set(Transaction.currencyKey, currency)
        try json.set(Transaction.amountKey, amount)
        try json.set(Transaction.directionKey, direction)
        try json.set(Transaction.createdKey, created)
        try json.set(Transaction.narrativeKey, narrative)
        try json.set(Transaction.sourceKey, source)
        try json.set(Transaction.balanceKey, balance)
        return json
    }

}

extension Transaction: ResponseRepresentable {}
