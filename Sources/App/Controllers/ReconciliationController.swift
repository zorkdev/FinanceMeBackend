import Vapor

final class ReconciliationController {

    private let spendingBusinessLogic = SpendingBusinessLogic()
    private let starlingTransactionsController = StarlingTransactionsController()

    func store(_ req: Request) throws -> ResponseRepresentable {
        let users = try User.all()

        for user in users {
            try spendingBusinessLogic.calculateEndOfMonthBalance(for: user)
        }

        return Response(status: .ok)
    }

    func addRoutes(to group: RouteBuilder) {
        group.add(.post, Routes.reconcile.rawValue, value: store)
    }

}

extension ReconciliationController: EmptyInitializable {}
