import Vapor
import Fluent

struct EndOfMonthSummariesResponse: Content {
    let currentMonthSummary: CurrentMonthSummary
    let endOfMonthSummaries: [EndOfMonthSummaryResponse]

    init(currentMonthSummary: CurrentMonthSummary,
         endOfMonthSummaries: [EndOfMonthSummaryResponse]) {
        self.currentMonthSummary = currentMonthSummary
        self.endOfMonthSummaries = endOfMonthSummaries
    }
}

struct EndOfMonthSummaryResponse: Content {
    var id: UUID?
    let created: Date
    let balance: Double
    let savings: Double
}

extension FieldKey {
    static var balance: Self { "balance" }
    static var savings: Self { "savings" }
}

final class EndOfMonthSummary: Model, Content {
    static let schema = "end_of_month_summarys"

    @ID()
    var id: UUID?

    @Field(key: .created)
    var created: Date

    @Field(key: .balance)
    var balance: Double

    @Field(key: .savings)
    var savings: Double

    @Parent(key: .userID)
    var user: User

    var response: EndOfMonthSummaryResponse {
        EndOfMonthSummaryResponse(id: id,
                                  created: created,
                                  balance: balance,
                                  savings: savings)
    }

    init() {}

    init(id: UUID? = nil,
         created: Date,
         balance: Double,
         savings: Double,
         userID: User.IDValue) {
        self.id = id
        self.created = created
        self.balance = balance
        self.savings = savings
        self.$user.id = userID
    }
}

struct CreateEndOfMonthSummary: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(EndOfMonthSummary.schema)
            .id()
            .field(.created, .datetime, .required)
            .field(.balance, .double, .required)
            .field(.savings, .double, .required)
            .foreignKey(.userID, references: User.schema, .id)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(EndOfMonthSummary.schema).delete()
    }
}
