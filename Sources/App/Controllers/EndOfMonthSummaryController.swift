import Vapor

final class EndOfMonthSummaryController: ResourceRepresentable {

    func index(_ req: Request) throws -> ResponseRepresentable {
        let user = try req.authUser()
        let endOfMonthSummaries = try user.endOfMonthSummaries.all()
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
