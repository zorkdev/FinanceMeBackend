import Vapor

extension Droplet {
    func setupRoutes() throws {
        get("/") { request in
            return try self.view.make("index.html")
        }
    }
}
