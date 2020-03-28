import Vapor
import Fluent

struct UserRequest: Content {
    let name: String
    let email: String
    let password: String
    let payday: Int
    let startDate: Date
    let largeTransaction: Double
    var allowance: Double
}

struct UserResponse: Content {
    let id: UUID?
    let name: String
    let payday: Int
    let startDate: Date
    let largeTransaction: Double
    var allowance: Double
    var balance: Double
}

struct LoginRequest: Content {
    let email: String
    let password: String
}

struct Session: Content {
    let token: String
}

extension FieldKey {
    static var userID: Self { "user_id" }
    static var name: Self { "name" }
    static var email: Self { "email" }
    static var password: Self { "password" }
    static var payday: Self { "payday" }
    static var startDate: Self { "startDate" }
    static var largeTransaction: Self { "largeTransaction" }
    static var sToken: Self { "sToken" }
    static var customerUid: Self { "customerUid" }
    static var deviceTokens: Self { "deviceTokens" }
    static var dailySpendingAverage: Self { "dailySpendingAverage" }
    static var dailyTravelSpendingAverage: Self { "dailyTravelSpendingAverage" }
    static var accountUid: Self { "accountUid" }
    static var categoryUid: Self { "categoryUid" }
}

final class User: Model, Content {
    static let schema = "users"

    @ID()
    var id: UUID?

    @Field(key: .name)
    var name: String

    @Field(key: .email)
    var email: String

    @Field(key: .password)
    var password: String

    @Field(key: .payday)
    var payday: Int

    @Field(key: .startDate)
    var startDate: Date

    @Field(key: .largeTransaction)
    var largeTransaction: Double

    @OptionalField(key: .sToken)
    var sToken: String?

    @OptionalField(key: .customerUid)
    var customerUid: String?

    @Field(key: .deviceTokens)
    var deviceTokens: [String]

    @Field(key: .dailySpendingAverage)
    var dailySpendingAverage: Double

    @Field(key: .dailyTravelSpendingAverage)
    var dailyTravelSpendingAverage: Double

    @OptionalField(key: .accountUid)
    var accountUid: UUID?

    @OptionalField(key: .categoryUid)
    var categoryUid: UUID?

    @Children(for: \.$user)
    var tokens: [Token]

    @Children(for: \.$user)
    var transactions: [Transaction]

    @Children(for: \.$user)
    var endOfMonthSummaries: [EndOfMonthSummary]

    var response: UserResponse {
        UserResponse(id: id,
                     name: name,
                     payday: payday,
                     startDate: startDate,
                     largeTransaction: largeTransaction,
                     allowance: 0,
                     balance: 0)
    }

    init() {}

    init(id: UUID? = nil,
         name: String,
         email: String,
         password: String,
         payday: Int,
         startDate: Date,
         largeTransaction: Double,
         sToken: String?,
         customerUid: String?,
         deviceTokens: [String],
         dailySpendingAverage: Double,
         dailyTravelSpendingAverage: Double) {
        self.id = id
        self.name = name
        self.email = email
        self.password = password
        self.payday = payday
        self.startDate = startDate
        self.largeTransaction = largeTransaction
        self.sToken = sToken
        self.customerUid = customerUid
        self.deviceTokens = deviceTokens
        self.dailySpendingAverage = dailySpendingAverage
        self.dailyTravelSpendingAverage = dailyTravelSpendingAverage
    }
}

extension User: ModelAuthenticatable {
    static let usernameKey = \User.$email
    static let passwordHashKey = \User.$password

    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.password)
    }
}

extension User {
    func generateToken() throws -> Token {
        try .init(token: [UInt8].random(count: 48).base64,
                  userID: requireID())
    }
}

struct CreateUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema)
            .id()
            .field(.name, .string, .required)
            .field(.email, .string, .required)
            .field(.password, .string, .required)
            .field(.payday, .int, .required)
            .field(.startDate, .datetime, .required)
            .field(.largeTransaction, .double, .required)
            .field(.sToken, .string)
            .field(.customerUid, .string)
            .field(.deviceTokens, .array(of: .string), .required)
            .field(.dailySpendingAverage, .double, .required)
            .field(.dailyTravelSpendingAverage, .double, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema).delete()
    }
}
