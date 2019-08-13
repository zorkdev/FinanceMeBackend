import Vapor

final class EndOfMonthSummaryController {
    private let spendingBusinessLogic = SpendingBusinessLogic()

    func index(_ req: Request) throws -> Future<EndOfMonthSummariesResponse> {
        let user = try req.requireAuthenticated(User.self)

        return try spendingBusinessLogic.calculateCurrentMonthSummary(for: user, on: req)
            .and(try user.endOfMonthSummaries.query(on: req).all())
            .map { EndOfMonthSummariesResponse(currentMonthSummary: $0,
                                               endOfMonthSummaries: $1.map { $0.response }) }
    }

    func addRoutes(to router: Router) {
        router.get(Routes.endOfMonthSummaries.rawValue, use: index)
    }
}
