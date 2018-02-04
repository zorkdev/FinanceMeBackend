import Vapor

final class EndOfMonthSummaryController: ResourceRepresentable {

    private let spendingBusinessLogic = SpendingBusinessLogic()

    func index(_ req: Request) throws -> ResponseRepresentable {
        let user = try req.authUser()
        let date = Date().next(day: user.payday, direction: .forward)
        let monthlyAllowance = try spendingBusinessLogic.calculateMonthlyAllowance(for: user)
        let summary = EndOfMonthSummary(created: date, balance: monthlyAllowance, user: nil)
        var endOfMonthSummaries = try user.endOfMonthSummaries.all()
        endOfMonthSummaries.append(summary)
        return try endOfMonthSummaries.makeJSON()
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
