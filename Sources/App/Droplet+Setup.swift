@_exported import Vapor

extension Droplet {
    public func setup() throws {
        try setupRoutes()
        StarlingClientController.shared.addTo(drop: self)
    }
}
