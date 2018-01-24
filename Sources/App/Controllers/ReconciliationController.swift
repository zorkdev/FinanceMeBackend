import Vapor

final class ReconciliationController {

    private let spendingBusinessLogic = SpendingBusinessLogic()
    private let starlingTransactionsController = StarlingTransactionsController()

    func store(_ req: Request) throws -> ResponseRepresentable {
        let users = try User.all()

        for user in users {
            let endOfMonthBalance = try spendingBusinessLogic.calculateEndOfMonthBalance(for: user)
            print(endOfMonthBalance)
        }

        return Response(status: .ok)
    }

    func addRoutes(to group: RouteBuilder) {
        group.add(.post, Routes.reconcile.rawValue, value: store)
    }

}

extension ReconciliationController: EmptyInitializable {}
