import Vapor

final class StarlingClientController {
    func get(endpoint: StarlingAPI,
             token: String,
             on con: Container) throws -> EventLoopFuture<Response> {
        let client = try con.client()
        var headers = HTTPHeaders()
        headers.bearerAuthorization = BearerAuthorization(token: token)

        return client.send(.GET, headers: headers, to: endpoint.uri)
    }

    func get<Parameters: Encodable>(endpoint: StarlingAPI,
                                    token: String,
                                    parameters: Parameters,
                                    on con: Container) throws -> EventLoopFuture<Response> {
        let client = try con.client()
        var headers = HTTPHeaders()
        headers.bearerAuthorization = BearerAuthorization(token: token)

        return client.send(.GET, headers: headers, to: endpoint.uri) { request in
            try request.query.encode(parameters)
        }
    }
}
