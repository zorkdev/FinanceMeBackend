import Vapor
import HTTP

final class StarlingClientController {

    private struct Constants {
        static let content = "application/json"

        static let authHeaderValue: (String) -> String = {
            return "Bearer \($0)"
        }
    }

    private var drop: Droplet?

    static let shared = StarlingClientController()

    private init() {}

    func addTo(drop: Droplet) {
        self.drop = drop
    }

    func performRequest(method: Method,
                        endpoint: StarlingAPI,
                        token: String,
                        parameters: [String: NodeRepresentable]?,
                        body: JSON = nil) throws -> Response {
        guard let drop = drop else { throw Abort.serverError}

        let headers: [HeaderKey: String] = [
            .accept: Constants.content,
            .authorization: Constants.authHeaderValue(token)
        ]

        let response = try drop.client.request(method,
                                               endpoint.uri,
                                               query: parameters ?? [:],
                                               headers,
                                               body,
                                               through: [])

        return response
    }
}
