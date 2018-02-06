import Vapor

final class ReconciliationController {

    private let spendingBusinessLogic = SpendingBusinessLogic()
    private let transactionsBusinessLogic = TransactionsBusinessLogic()

    func store(_ req: Request) throws -> ResponseRepresentable {
        let users = try User.all()

        for user in users {
            try transactionsBusinessLogic.updateTransactions(user: user)
            try spendingBusinessLogic.calculateEndOfMonthBalance(for: user)
        }

        return Response(status: .ok)
    }

    func addRoutes(to group: RouteBuilder) {
        group.add(.post, Routes.reconcile.rawValue, value: store)
    }

}

extension ReconciliationController: EmptyInitializable {}
