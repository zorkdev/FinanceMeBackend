import Vapor
import FluentProvider
import Crypto

final class Token: Model {

    private struct Constants {
        static let idKey = "id"
        static let tokenKey = "token"
        static let userIdKey = "userId"

        static let tokenBytes = 48
    }

    let storage = Storage()

    let token: String
    let userId: Identifier?

    var user: Parent<Token, User> {
        return parent(id: userId)
    }

    init(token: String,
         user: User) {
        self.token = token
        self.userId = user.id
    }

    init(row: Row) throws {
        token = try row.get(Constants.tokenKey)
        userId = try row.get(User.foreignIdKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Constants.tokenKey, token)
        try row.set(User.foreignIdKey, userId)
        return row
    }

}

extension Token: Preparation {

    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Constants.tokenKey)
            builder.parent(User.self)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete(self)
    }

}

extension Token: JSONConvertible {

    convenience init(json: JSON) throws {
        let userId: Identifier = try json.get(Constants.userIdKey)
        guard let user = try User.find(userId) else { throw Abort.badRequest }
        try self.init(token: json.get(Constants.tokenKey),
                      user: user)
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Constants.tokenKey, token)
        return json
    }

}

extension Token: ResponseRepresentable {}

extension Token {

    static func generate(for user: User) throws -> Token {
        let random = try Crypto.Random.bytes(count: Constants.tokenBytes)
        return Token(token: random.base64Encoded.makeString(), user: user)
    }

}
