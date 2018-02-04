import Vapor

final class CurrentMonthSummary {

    struct Constants {
        static let allowanceKey = "allowance"
        static let forecastKey = "forecast"
    }

    let allowance: Double
    let forecast: Double

    init(allowance: Double,
         forecast: Double) {
        self.allowance = allowance
        self.forecast = forecast
    }

}

extension CurrentMonthSummary: JSONConvertible {

    convenience init(json: JSON) throws {
        try self.init(allowance: json.get(Constants.allowanceKey),
                      forecast: json.get(Constants.forecastKey))
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Constants.allowanceKey, allowance)
        try json.set(Constants.forecastKey, forecast)
        return json
    }

}

extension CurrentMonthSummary: ResponseRepresentable {}
