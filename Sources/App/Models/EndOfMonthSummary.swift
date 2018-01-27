import Vapor
import FluentProvider

final class EndOfMonthSummary: Model {

    struct Constants {
        static let idKey = "id"
        static let createdKey = "created"
        static let balanceKey = "balance"
    }

    let storage = Storage()

    let created: Date
    let balance: Double

    var userId: Identifier?

    var user: Parent<EndOfMonthSummary, User> {
        return parent(id: userId)
    }

    init(created: Date,
         balance: Double,
         user: User?) {
        self.created = created
        self.balance = balance
        self.userId = user?.id
    }

    init(row: Row) throws {
        created = try row.get(Constants.createdKey)
        balance = try row.get(Constants.balanceKey)
        userId = try row.get(User.foreignIdKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Constants.createdKey, created)
        try row.set(Constants.balanceKey, balance)
        try row.set(User.foreignIdKey, userId)
        return row
    }

}

extension EndOfMonthSummary: Preparation {

    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.date(Constants.createdKey)
            builder.double(Constants.balanceKey)
            builder.parent(User.self)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete(self)
    }

}

extension EndOfMonthSummary: JSONConvertible {

    convenience init(json: JSON) throws {
        try self.init(created: json.get(Constants.createdKey),
                      balance: json.get(Constants.balanceKey),
                      user: nil)
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Constants.idKey, id)
        try json.set(Constants.createdKey, created)
        try json.set(Constants.balanceKey, balance)
        return json
    }

}

extension EndOfMonthSummary: ResponseRepresentable {}
