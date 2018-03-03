import Vapor
import FluentProvider
import AuthProvider

final class User: Model {

    private struct Constants {
        static let idKey = "id"
        static let tokenKey = "token"
        static let nameKey = "name"
        static let emailKey = "email"
        static let passwordKey = "password"
        static let paydayKey = "payday"
        static let startDateKey = "startDate"
        static let largeTransactionKey = "largeTransaction"
        static let sTokenKey = "sToken"
    }

    let storage = Storage()

    var name: String
    var email: String
    var password: String
    var payday: Int
    var startDate: Date
    var largeTransaction: Double
    var sToken: String?

    var token: Children<User, Token> {
        return children()
    }

    var transactions: Children<User, Transaction> {
        return children()
    }

    var endOfMonthSummaries: Children<User, EndOfMonthSummary> {
        return children()
    }

    init(name: String,
         email: String,
         password: String,
         payday: Int,
         startDate: Date,
         largeTransaction: Double,
         sToken: String?) {
        self.name = name
        self.email = email
        self.password = password
        self.payday = payday
        self.startDate = startDate
        self.largeTransaction = largeTransaction
        self.sToken = sToken
    }

    init(row: Row) throws {
        name = try row.get(Constants.nameKey)
        email = try row.get(Constants.emailKey)
        password = try row.get(Constants.passwordKey)
        payday = try row.get(Constants.paydayKey)
        startDate = try row.get(Constants.startDateKey)
        largeTransaction = try row.get(Constants.largeTransactionKey)
        sToken = try row.get(Constants.sTokenKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Constants.nameKey, name)
        try row.set(Constants.emailKey, email)
        try row.set(Constants.passwordKey, password)
        try row.set(Constants.paydayKey, payday)
        try row.set(Constants.startDateKey, startDate)
        try row.set(Constants.largeTransactionKey, largeTransaction)
        try row.set(Constants.sTokenKey, sToken)
        return row
    }

}

extension User: Preparation {

    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Constants.nameKey)
            builder.string(Constants.emailKey)
            builder.string(Constants.passwordKey)
            builder.int(Constants.paydayKey)
            builder.date(Constants.startDateKey)
            builder.double(Constants.largeTransactionKey)
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
                      email: (try? json.get(Constants.emailKey)) ?? "",
                      password: (try? json.get(Constants.passwordKey)) ?? "",
                      payday: json.get(Constants.paydayKey),
                      startDate: json.get(Constants.startDateKey),
                      largeTransaction: json.get(Constants.largeTransactionKey),
                      sToken: nil)
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(User.idKey, id)
        try json.set(Constants.nameKey, name)
        try json.set(Constants.paydayKey, payday)
        try json.set(Constants.startDateKey, startDate)
        try json.set(Constants.largeTransactionKey, largeTransaction)
        return json
    }

    func makeLoginJSON() throws -> JSON {
        var json = JSON()
        try json.set(Constants.tokenKey, token.first()?.token)
        try json.set(Constants.sTokenKey, sToken)
        return json
    }

}

extension User: TokenAuthenticatable {

    public typealias TokenType = Token

}

extension User: ResponseRepresentable {}
extension User: PasswordAuthenticatable {

    var hashedPassword: String? {
        return password
    }

    static var passwordVerifier: PasswordVerifier? {
        return HashPasswordVerifier()
    }

}

struct HashPasswordVerifier: PasswordVerifier {

    static let hasher = BCryptHasher(cost: 7)

    func verify(password: Bytes, matches hash: Bytes) throws -> Bool {
        return try HashPasswordVerifier.hasher.check(password, matchesHash: hash)
    }

}
