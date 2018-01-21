//
//  Transaction.swift
//  zorkdev
//
//  Created by Attila Nemet on 22/01/2018.
//

import Vapor
import FluentProvider

enum TransactionDirection: String {

    case none = "NONE"
    case outbound = "OUTBOUND"
    case inbound = "INBOUND"

}

enum TransactionSource: String {

    case directCredit = "DIRECT_CREDIT"
    case directDebit = "DIRECT_DEBIT"
    case directDebitDispute = "DIRECT_DEBIT_DISPUTE"
    case internalTransfer = "INTERNAL_TRANSFER"
    case masterCard = "MASTER_CARD"
    case fasterPaymentsIn = "FASTER_PAYMENTS_IN"
    case fasterPaymentsOut = "FASTER_PAYMENTS_OUT"
    case fasterPaymentsReversal = "FASTER_PAYMENTS_REVERSAL"
    case stripeFunding = "STRIPE_FUNDING"
    case interestPayment = "INTEREST_PAYMENT"
    case nostroDeposit = "NOSTRO_DEPOSIT"
    case overdraft = "OVERDRAFT"
    case externelRegularInbound = "EXTERNAL_REGULAR_INBOUND"
    case externalRegularOutbound = "EXTERNAL_REGULAR_OUTBOUND"
    case externalInbound = "EXTERNAL_INBOUND"
    case externalOutbound = "EXTERNAL_OUTBOUND"

}

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
    let direction: TransactionDirection
    let created: Date
    let narrative: String
    let source: TransactionSource
    let balance: Double

    var userId: Identifier?

    var user: Parent<Transaction, User> {
        return parent(id: userId)
    }

    init(currency: String,
         amount: Double,
         direction: TransactionDirection,
         created: Date,
         narrative: String,
         source: TransactionSource,
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
        created = try row.get(Transaction.createdKey)
        narrative = try row.get(Transaction.narrativeKey)
        balance = try row.get(Transaction.balanceKey)
        userId = try row.get(User.foreignIdKey)

        let directionString: String = try row.get(Transaction.directionKey)
        guard let directionEnum = TransactionDirection(rawValue: directionString) else {
            throw Abort.serverError
        }
        direction = directionEnum

        let sourceString: String = try row.get(Transaction.sourceKey)
        guard let sourceEnum = TransactionSource(rawValue: sourceString) else {
            throw Abort.serverError
        }
        source = sourceEnum
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Transaction.currencyKey, currency)
        try row.set(Transaction.amountKey, amount)
        try row.set(Transaction.directionKey, direction.rawValue)
        try row.set(Transaction.createdKey, created)
        try row.set(Transaction.narrativeKey, narrative)
        try row.set(Transaction.sourceKey, source.rawValue)
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
        let directionString: String = try json.get(Transaction.directionKey)
        guard let direction = TransactionDirection(rawValue: directionString) else {
            throw NodeError.invalidDictionaryKeyType
        }

        let sourceString: String = try json.get(Transaction.sourceKey)
        guard let source = TransactionSource(rawValue: sourceString) else {
            throw NodeError.invalidDictionaryKeyType
        }

        try self.init(currency: json.get(Transaction.currencyKey),
                      amount: json.get(Transaction.amountKey),
                      direction: direction,
                      created: json.get(Transaction.createdKey),
                      narrative: json.get(Transaction.narrativeKey),
                      source: source,
                      balance: json.get(Transaction.balanceKey),
                      user: nil)
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Transaction.idKey, id)
        try json.set(Transaction.currencyKey, currency)
        try json.set(Transaction.amountKey, amount)
        try json.set(Transaction.directionKey, direction.rawValue)
        try json.set(Transaction.createdKey, created)
        try json.set(Transaction.narrativeKey, narrative)
        try json.set(Transaction.sourceKey, source.rawValue)
        try json.set(Transaction.balanceKey, balance)
        return json
    }

}

extension Transaction: ResponseRepresentable {}
