import Vapor
import FluentPostgreSQL

final class MetricController {
    func store(_ req: Request) throws -> Future<HTTPStatus> {
        guard let data = req.http.body.data else { return req.eventLoop.newSucceededFuture(result: .badRequest) }
        let metric = Metric(payload: data)
        return metric.save(on: req).map { _ in HTTPStatus.ok }
    }

    func addPublicRoutes(to router: Router) {
        router.post(Routes.metrics.rawValue, use: store)
    }
}
