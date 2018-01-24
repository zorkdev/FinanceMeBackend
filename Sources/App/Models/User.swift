import Vapor
import FluentProvider
import AuthProvider

final class User: Model {

    private struct Constants {
        static let idKey = "id"
        static let tokenKey = "token"
        static let nameKey = "name"
        static let paydayKey = "payday"
        static let endOfMonthBalanceKey = "endOfMonthBalance"
        static let spendingLimitKey = "spendingLimit"
        static let sTokenKey = "sToken"
    }

    private let spendingBusinessLogic = SpendingBusinessLogic()

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
        return spendingBusinessLogic.calculateAmountSum(from: transactions)
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
        name = try row.get(Constants.nameKey)
        payday = try row.get(Constants.paydayKey)
        endOfMonthBalance = try row.get(Constants.endOfMonthBalanceKey)
        sToken = try row.get(Constants.sTokenKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Constants.nameKey, name)
        try row.set(Constants.paydayKey, payday)
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
            builder.double(Constants.endOfMonthBalanceKey)
            builder.double(Constants.sTokenKey, optional: true, unique: false, default: nil)
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
        try json.set(Constants.endOfMonthBalanceKey, endOfMonthBalance)
        try json.set(Constants.spendingLimitKey, spendingLimit)
        return json
    }

}

extension User: ResponseRepresentable {}

extension User: TokenAuthenticatable {

    public typealias TokenType = Token

}
