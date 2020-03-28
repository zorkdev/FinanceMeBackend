import Vapor
import Fluent

final class MetricController {
    func store(_ req: Request) -> EventLoopFuture<HTTPStatus> {
        guard let bytes = req.body.data?.readableBytesView else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest))
        }
        let data = Data(bytes)
        let metric = Metric(payload: data)
        return metric.save(on: req.db)
            .transform(to: .ok)
    }

    func addPublicRoutes(to router: RoutesBuilder) {
        router.post(Routes.metrics.path, use: store)
    }
}
