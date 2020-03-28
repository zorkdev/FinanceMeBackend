import Vapor

final class HealthController {
    func show(_ req: Request) -> EventLoopFuture<Health> {
        req.eventLoop.makeSucceededFuture(Health())
    }

    func addPublicRoutes(to router: RoutesBuilder) {
        router.get(Routes.health.path, use: show)
    }
}
