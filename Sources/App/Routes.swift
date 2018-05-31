import Vapor
import AuthProvider

enum Routes: String {

    case root = "/"
    case index = "index.html"
    case api = "api"
    case login = "login"
    case users = "users"
    case usersMe = "users/me"
    case transactions = "transactions"
    case transactionPayload = "transactions/payload"
    case reconcile = "reconcile"
    case endOfMonthSummaries = "endOfMonthSummaries"

}

extension Droplet {
    func setupRoutes() throws {
        get(Routes.root.rawValue) { _ in
            return try self.view.make(Routes.index.rawValue)
        }

        let apiGroup = grouped(Routes.api.rawValue)
        let tokenGroup = apiGroup.grouped([TokenAuthenticationMiddleware(User.self)])

        let userController = UserController()
        userController.addRoutes(to: tokenGroup)
        userController.addPublicRoutes(to: apiGroup)

        let transactionController = TransactionController()
        try transactionController.addRoutes(to: tokenGroup)
        transactionController.addPublicRoutes(to: apiGroup)

        let reconciliationController = ReconciliationController()
        reconciliationController.addRoutes(to: apiGroup)

        let endOfMonthSummaryController = EndOfMonthSummaryController()
        try endOfMonthSummaryController.addRoutes(to: tokenGroup)
    }
}
