import Vapor
import FluentPostgreSQL
import Authentication

final class Token: PostgreSQLUUIDModel {
    private enum CodingKeys: String, CodingKey {
        case id
        case token
        case userID = "user_id"
    }

    static let entity = "tokens"

    private enum Constants {
        static let tokenBytes = 48
    }

    var id: UUID?
    var token: String

    var userID: User.ID

    var user: Parent<Token, User> {
        parent(\.userID)
    }

    init(id: UUID? = nil,
         token: String,
         userID: User.ID) {
        self.id = id
        self.token = token
        self.userID = userID
    }
}

extension Token: Authentication.Token {
    typealias UserType = User

    static var userIDKey: WritableKeyPath<Token, User.ID> {
        \.userID
    }

    static var tokenKey: WritableKeyPath<Token, String> {
        \.token
    }

    static func generate(for user: User) throws -> Token {
        let random = try CryptoRandom().generateData(count: Constants.tokenBytes)
        guard let string = String(bytes: random.base64EncodedData(), encoding: .ascii),
            let userID = user.id else {
            throw Abort(.internalServerError)
        }
        return Token(token: string, userID: userID)
    }
}

extension Token: Migration {}
extension Token: Content {}
extension Token: Parameter {}
