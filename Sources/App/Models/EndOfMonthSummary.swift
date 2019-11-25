import Vapor
import FluentPostgreSQL

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

final class EndOfMonthSummary: PostgreSQLUUIDModel {
    private enum CodingKeys: String, CodingKey {
        case id
        case created
        case balance
        case savings
        case userID = "user_id"
    }

    static let entity = "end_of_month_summarys"

    var id: UUID?
    let created: Date
    let balance: Double
    let savings: Double

    var userID: User.ID

    var user: Parent<EndOfMonthSummary, User> {
        return parent(\.userID)
    }

    var response: EndOfMonthSummaryResponse {
        return EndOfMonthSummaryResponse(id: id,
                                         created: created,
                                         balance: balance,
                                         savings: savings)
    }

    init(id: UUID? = nil,
         created: Date,
         balance: Double,
         savings: Double,
         userID: User.ID) {
        self.id = id
        self.created = created
        self.balance = balance
        self.savings = savings
        self.userID = userID
    }
}

extension EndOfMonthSummary: Migration {}
extension EndOfMonthSummary: Content {}
extension EndOfMonthSummary: Parameter {}
