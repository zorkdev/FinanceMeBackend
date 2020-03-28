import Vapor
import Fluent

extension FieldKey {
    static var token: Self { "token" }
}

final class Token: Model, Content {
    private enum Constants {
        static let tokenBytes = 48
    }

    static let schema = "tokens"

    @ID()
    var id: UUID?

    @Field(key: .token)
    var token: String

    @Parent(key: .userID)
    var user: User

    init() {}

    init(id: UUID? = nil,
         token: String,
         userID: User.IDValue) {
        self.id = id
        self.token = token
        self.$user.id = userID
    }
}

extension Token: ModelTokenAuthenticatable {
    static let valueKey = \Token.$token
    static let userKey = \Token.$user

    var isValid: Bool { true }
}

struct CreateToken: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Token.schema)
            .id()
            .field(.token, .string, .required)
            .foreignKey(.userID, references: User.schema, .id)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Token.schema).delete()
    }
}
