import Vapor

final class StarlingClientController {

    func get<Parameters: Encodable>(endpoint: StarlingAPI,
                                    token: String,
                                    parameters: Parameters? = nil,
                                    on con: Container) throws -> Future<Response> {
        let client = try con.client()
        var headers = HTTPHeaders()
        headers.bearerAuthorization = BearerAuthorization(token: token)

        return client.send(.GET, headers: headers, to: endpoint.uri) { request in
            if let parameters = parameters {
                try request.query.encode(parameters)
            }
        }

    }

}
