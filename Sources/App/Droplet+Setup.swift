@_exported import Vapor

var logger: LogProtocol!

extension Droplet {
    public func setup() throws {
        try setupRoutes()
        StarlingClientController.shared.addTo(drop: self)
        logger = self.log
    }
}
