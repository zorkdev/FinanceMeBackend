import Vapor

final class ReconciliationController {

    private let starlingTransactionsController = StarlingTransactionsController()

    func store(_ req: Request) throws -> ResponseRepresentable {
        let users = try User.all()

        for user in users {
            let transactions = try starlingTransactionsController.getTransactions(user: user)
            print(transactions)
        }

        return Response(status: .ok)
    }

    func addRoutes(to group: RouteBuilder) {
        group.add(.post, Routes.reconcile.rawValue, value: store)
    }

}

extension ReconciliationController: EmptyInitializable {}
