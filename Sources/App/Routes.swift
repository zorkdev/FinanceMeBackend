import Vapor
import AuthProvider

extension Droplet {
    func setupRoutes() throws {
        get("/") { request in
            return try self.view.make("index.html")
        }

        let apiGroup = grouped("api")
        let tokenGroup = apiGroup.grouped([TokenAuthenticationMiddleware(User.self)])

        let userController = UserController()
        try userController.addRoutes(to: tokenGroup)
        try userController.addPublicRoutes(to: apiGroup)

        let transactionController = TransactionController()
        try transactionController.addRoutes(to: tokenGroup)
    }
}
