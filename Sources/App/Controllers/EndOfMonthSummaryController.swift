import Vapor

final class EndOfMonthSummaryController: ResourceRepresentable {

    private struct Constants {
        static let currentMonthSummaryKey = "currentMonthSummary"
        static let endOfMonthSummariesKey = "endOfMonthSummaries"
    }

    private let spendingBusinessLogic = SpendingBusinessLogic()

    func index(_ req: Request) throws -> ResponseRepresentable {
        let user = try req.authUser()
        let currentMonthSummary = try spendingBusinessLogic.calculateCurrentMonthSummary(for: user)
        let endOfMonthSummaries = try user.endOfMonthSummaries.all()
        var json = JSON()
        try json.set(Constants.currentMonthSummaryKey, currentMonthSummary)
        try json.set(Constants.endOfMonthSummariesKey, endOfMonthSummaries)
        return json
    }

    func makeResource() -> Resource<Transaction> {
        return Resource(
            index: index
        )
    }

    func addRoutes(to group: RouteBuilder) throws {
        try group.resource(Routes.endOfMonthSummaries.rawValue, EndOfMonthSummaryController.self)
    }

}

extension EndOfMonthSummaryController: EmptyInitializable {}
