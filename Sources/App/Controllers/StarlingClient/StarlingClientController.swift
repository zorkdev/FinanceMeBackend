import Vapor

final class StarlingClientController {
    func get(endpoint: StarlingAPI,
             token: String,
             on req: Request) -> EventLoopFuture<ClientResponse> {
        var headers = HTTPHeaders()
        headers.bearerAuthorization = BearerAuthorization(token: token)

        return req.client.send(.GET, headers: headers, to: endpoint.uri)
    }

    func get<Parameters: Encodable>(endpoint: StarlingAPI,
                                    token: String,
                                    parameters: Parameters,
                                    on req: Request) -> EventLoopFuture<ClientResponse> {
        var headers = HTTPHeaders()
        headers.bearerAuthorization = BearerAuthorization(token: token)

        return req.client.send(.GET, headers: headers, to: endpoint.uri) { request in
            try request.query.encode(parameters)
        }
    }
}
