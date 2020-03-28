import Vapor

final class EndOfMonthSummaryController {
    private let spendingBusinessLogic = SpendingBusinessLogic()

    func index(_ req: Request) throws -> EventLoopFuture<EndOfMonthSummariesResponse> {
        let user = try req.auth.require(User.self)

        return spendingBusinessLogic.calculateCurrentMonthSummary(for: user, on: req)
            .and(user.$endOfMonthSummaries.query(on: req.db).all())
            .map {
                EndOfMonthSummariesResponse(currentMonthSummary: $0,
                                            endOfMonthSummaries: $1.map { $0.response })
            }
    }

    func addRoutes(to router: RoutesBuilder) {
        router.get(Routes.endOfMonthSummaries.path, use: index)
    }
}
