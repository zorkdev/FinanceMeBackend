import Vapor
import FluentProvider
import AuthProvider

final class User: Model {

    private struct Constants {
        static let idKey = "id"
        static let tokenKey = "token"
        static let nameKey = "name"
        static let paydayKey = "payday"
        static let startDateKey = "startDate"
        static let largeTransactionKey = "largeTransaction"
        static let endOfMonthBalanceKey = "endOfMonthBalance"
        static let spendingLimitKey = "spendingLimit"
        static let allowanceKey = "allowance"
        static let sTokenKey = "sToken"
    }

    private let spendingBusinessLogic = SpendingBusinessLogic()

    let storage = Storage()

    let name: String
    let payday: Int
    let startDate: Date
    let largeTransaction: Double
    let endOfMonthBalance: Double
    var sToken: String?

    var token: Children<User, Token> {
        return children()
    }

    var transactions: Children<User, Transaction> {
        return children()
    }

    var allowance: Double {
        return (try? spendingBusinessLogic.calculateAllowance(for: self)) ?? 0
    }

    init(name: String,
         payday: Int,
         startDate: Date,
         largeTransaction: Double,
         endOfMonthBalance: Double,
         sToken: String?) {
        self.name = name
        self.payday = payday
        self.startDate = startDate
        self.largeTransaction = largeTransaction
        self.endOfMonthBalance = endOfMonthBalance
        self.sToken = sToken
    }

    init(row: Row) throws {
        name = try row.get(Constants.nameKey)
        payday = try row.get(Constants.paydayKey)
        startDate = try row.get(Constants.startDateKey)
        largeTransaction = try row.get(Constants.largeTransactionKey)
        endOfMonthBalance = try row.get(Constants.endOfMonthBalanceKey)
        sToken = try row.get(Constants.sTokenKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Constants.nameKey, name)
        try row.set(Constants.paydayKey, payday)
        try row.set(Constants.startDateKey, startDate)
        try row.set(Constants.largeTransactionKey, largeTransaction)
        try row.set(Constants.endOfMonthBalanceKey, endOfMonthBalance)
        try row.set(Constants.sTokenKey, sToken)
        return row
    }

}

extension User: Preparation {

    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Constants.nameKey)
            builder.int(Constants.paydayKey)
            builder.date(Constants.startDateKey)
            builder.double(Constants.largeTransactionKey)
            builder.double(Constants.endOfMonthBalanceKey)
            builder.string(Constants.sTokenKey, optional: true)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete(self)
    }

}

extension User: JSONConvertible {

    convenience init(json: JSON) throws {
        try self.init(name: json.get(Constants.nameKey),
                      payday: json.get(Constants.paydayKey),
                      startDate: json.get(Constants.startDateKey),
                      largeTransaction: json.get(Constants.largeTransactionKey),
                      endOfMonthBalance: json.get(Constants.endOfMonthBalanceKey),
                      sToken: nil)
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(User.idKey, id)
        let tokenString = try token.first()?.token
        try json.set(User.tokenKey, tokenString)
        try json.set(Constants.nameKey, name)
        try json.set(Constants.paydayKey, payday)
        try json.set(Constants.startDateKey, startDate)
        try json.set(Constants.largeTransactionKey, largeTransaction)
        try json.set(Constants.endOfMonthBalanceKey, endOfMonthBalance)
        try json.set(Constants.allowanceKey, allowance)
        return json
    }

}

extension User: TokenAuthenticatable {

    public typealias TokenType = Token

}

extension User: ResponseRepresentable {}
