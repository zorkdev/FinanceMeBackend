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

    var isExternal: Bool {
        switch self {
        case .externalInbound,
             .externalOutbound,
             .externelRegularInbound,
             .externalRegularOutbound:
            return true
        default:
            return false
        }
    }

}

final class Transaction: Model {

    struct Constants {
        static let idKey = "id"
        static let currencyKey = "currency"
        static let amountKey = "amount"
        static let directionKey = "direction"
        static let createdKey = "created"
        static let narrativeKey = "narrative"
        static let sourceKey = "source"
        static let balanceKey = "balance"
    }

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
        currency = try row.get(Constants.currencyKey)
        amount = try row.get(Constants.amountKey)
        created = try row.get(Constants.createdKey)
        narrative = try row.get(Constants.narrativeKey)
        balance = try row.get(Constants.balanceKey)
        userId = try row.get(User.foreignIdKey)

        let directionString: String = try row.get(Constants.directionKey)
        guard let directionEnum = TransactionDirection(rawValue: directionString) else {
            throw Abort.serverError
        }
        direction = directionEnum

        let sourceString: String = try row.get(Constants.sourceKey)
        guard let sourceEnum = TransactionSource(rawValue: sourceString) else {
            throw Abort.serverError
        }
        source = sourceEnum
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Constants.currencyKey, currency)
        try row.set(Constants.amountKey, amount)
        try row.set(Constants.directionKey, direction.rawValue)
        try row.set(Constants.createdKey, created)
        try row.set(Constants.narrativeKey, narrative)
        try row.set(Constants.sourceKey, source.rawValue)
        try row.set(Constants.balanceKey, balance)
        try row.set(User.foreignIdKey, userId)
        return row
    }

}

extension Transaction: Preparation {

    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Constants.currencyKey)
            builder.double(Constants.amountKey)
            builder.string(Constants.directionKey)
            builder.date(Constants.createdKey)
            builder.string(Constants.narrativeKey)
            builder.string(Constants.sourceKey)
            builder.double(Constants.balanceKey)
            builder.parent(User.self)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete(self)
    }

}

extension Transaction: JSONConvertible {

    convenience init(json: JSON) throws {
        let directionString: String = try json.get(Constants.directionKey)
        guard let direction = TransactionDirection(rawValue: directionString) else {
            throw NodeError.invalidDictionaryKeyType
        }

        let sourceString: String = try json.get(Constants.sourceKey)
        guard let source = TransactionSource(rawValue: sourceString) else {
            throw NodeError.invalidDictionaryKeyType
        }

        try self.init(currency: json.get(Constants.currencyKey),
                      amount: json.get(Constants.amountKey),
                      direction: direction,
                      created: json.get(Constants.createdKey),
                      narrative: json.get(Constants.narrativeKey),
                      source: source,
                      balance: json.get(Constants.balanceKey),
                      user: nil)

        if let id: Identifier = try json.get(Constants.idKey) {
            self.id = id
        }
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Constants.idKey, id)
        try json.set(Constants.currencyKey, currency)
        try json.set(Constants.amountKey, amount)
        try json.set(Constants.directionKey, direction.rawValue)
        try json.set(Constants.createdKey, created)
        try json.set(Constants.narrativeKey, narrative)
        try json.set(Constants.sourceKey, source.rawValue)
        try json.set(Constants.balanceKey, balance)
        return json
    }

}

extension Transaction: ResponseRepresentable {}
