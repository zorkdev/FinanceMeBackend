import Vapor

final class PushNotificationController {
    var certPath: String {
        let directory = DirectoryConfig.detect()
        let workingDirectory = directory.workDir
        return URL(fileURLWithPath: workingDirectory)
            .appendingPathComponent("apns.pem", isDirectory: false)
            .path
    }

    private let spendingBusinessLogic = SpendingBusinessLogic()

    func store(_ req: Request) throws -> Future<HTTPStatus> {
        let user = try req.requireAuthenticated(User.self)

        return try req.content.decode(DeviceTokenRequest.self)
            .flatMap { deviceTokenRequest in
                let token = deviceTokenRequest.deviceToken
                guard user.deviceTokens.contains(token) == false else {
                    return req.eventLoop.newSucceededFuture(result: .ok)
                }
                user.deviceTokens.append(token)
                return user.save(on: req).transform(to: .ok)
        }
    }

    func sendNotification(user: User, on req: Request) throws -> Future<[Data]> {
        return try spendingBusinessLogic.calculateAllowance(for: user, on: req)
            .flatMap { try self.sendNotification(user: user, allowance: $0, on: req) }
    }

    func sendNotification(user: User, allowance: Double, on req: Request) throws -> Future<[Data]> {
        return try user.deviceTokens
            .map { try self.sendNotification(deviceToken: $0,
                                             allowance: allowance,
                                             on: req) }
            .flatten(on: req)
    }

    func sendNotification(deviceToken: String, allowance: Double, on req: Request) throws -> Future<Data> {
        let shell = try Shell.makeService(for: req)
        let pw = ProcessInfo.processInfo.environment["APNS_CERT_PW"]!

        let payload = "{\"aps\":{\"content-available\":1},\"allowance\":\(allowance)}"

        let arguments = [
            "-d", "\(payload)",
            "-H", "Content-Type: application/json",
            "-H", "apns-topic:com.zorkdev.MyFinance.iOS.complication",
            "-H", "apns-expiration: 1",
            "-H", "apns-priority: 10",
            "https://api.push.apple.com/3/device/\(deviceToken)",
            "-E", "\(certPath):\(pw)",
            "--http2-prior-knowledge"
        ]

        return try shell.execute(commandName: "curl", arguments: arguments).map { response in
            try req.make(Logger.self).info(String(data: response, encoding: .utf8) ?? "Empty body")
            return response
        }
    }

    func addRoutes(to router: Router) {
        router.post(Routes.deviceToken.rawValue, use: store)
    }
}
