import Vapor
import FluentPostgreSQL
import Authentication

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

final class User: PostgreSQLUUIDModel {
    static let entity = "users"

    var id: UUID?
    var name: String
    var email: String
    var password: String
    var payday: Int
    var startDate: Date
    var largeTransaction: Double
    var sToken: String?
    var customerUid: String?
    var deviceTokens: [String]
    var dailySpendingAverage: Double
    var dailyTravelSpendingAverage: Double
    var accountUid: UUID?
    var categoryUid: UUID?

    var token: Children<User, Token> {
        return children(\.userID)
    }

    var transactions: Children<User, Transaction> {
        return children(\.userID)
    }

    var endOfMonthSummaries: Children<User, EndOfMonthSummary> {
        return children(\.userID)
    }

    var response: UserResponse {
        return UserResponse(id: id,
                            name: name,
                            payday: payday,
                            startDate: startDate,
                            largeTransaction: largeTransaction,
                            allowance: 0,
                            balance: 0)
    }

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

extension User: TokenAuthenticatable {
    typealias TokenType = Token
}

extension User: PasswordAuthenticatable {
    static var usernameKey: WritableKeyPath<User, String> {
        return \.email
    }

    static var passwordKey: WritableKeyPath<User, String> {
        return \.password
    }
}

extension User: Migration {}
extension User: Content {}
extension User: Parameter {}
