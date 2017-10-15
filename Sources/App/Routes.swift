import Vapor

extension Droplet {
    func setupRoutes() throws {
        get("/") { request in
            return try self.view.make("index.html")
        }

        let apiGroup = grouped("api")

        let userController = UserController()
        try userController.addRoutes(to: apiGroup)

        let categoryController = CategoryController()
        try categoryController.addRoutes(to: apiGroup)

        let reminderController = ReminderController()
        try reminderController.addRoutes(to: apiGroup)
    }
}
