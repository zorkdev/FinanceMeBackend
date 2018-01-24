import Vapor
import AuthProvider

enum Routes: String {

    case root = "/"
    case index = "index.html"
    case api = "api"
    case users = "users"
    case usersMe = "users/me"
    case transactions = "transactions"
    case reconcile = "reconcile"

}

extension Droplet {
    func setupRoutes() throws {
        get(Routes.root.rawValue) { request in
            return try self.view.make(Routes.index.rawValue)
        }

        let apiGroup = grouped(Routes.api.rawValue)
        let tokenGroup = apiGroup.grouped([TokenAuthenticationMiddleware(User.self)])

        let userController = UserController()
        userController.addRoutes(to: tokenGroup)
        userController.addPublicRoutes(to: apiGroup)

        let transactionController = TransactionController()
        try transactionController.addRoutes(to: tokenGroup)

        let reconciliationController = ReconciliationController()
        reconciliationController.addRoutes(to: apiGroup)
    }
}
