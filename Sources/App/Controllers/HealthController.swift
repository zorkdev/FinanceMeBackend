import Vapor

final class HealthController {
    func show(_ req: Request) throws -> EventLoopFuture<Health> {
        req.eventLoop.newSucceededFuture(result: Health())
    }

    func addPublicRoutes(to router: Router) {
        router.get(Routes.health.rawValue, use: show)
    }
}
