import Vapor
import HTTP
import Foundation

public final class GzipMiddleware: Middleware {

    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        let response = try next.respond(to: request)
        
        if request.requiresGzip && response.gzippable && !response.isGzipped {
            if
                let bytes = response.body.bytes,
                let data = try? Data(bytes: bytes).gzipped() {
                let dataBody = data.makeBytes()
                
                response.body = .data(dataBody)
                response.headers["Content-Encoding"] = "gzip"
                response.headers["Content-Length"] = "\(data.count)"
            }
        }
        
        return response
    }
    
    public init() {}
}

extension Request {
    var requiresGzip: Bool {
        return self.headers["Accept-Encoding"]?.contains("gzip") ?? false
    }
}

extension Response {
    var gzippable: Bool {
        guard let contentType = contentType else { return false }
        if contentType.contains("text/html") || contentType.contains("application/javascript")  || contentType.contains("application/json") || contentType.contains("text/css") {
            return true
        }
        return false
    }
    
    var isGzipped: Bool {
        guard let data = self.body.bytes else { return false }
        return Data(bytes: data).isGzipped
    }
}
