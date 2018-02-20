import Vapor

final class CurrentMonthSummary {

    struct Constants {
        static let allowanceKey = "allowance"
        static let forecastKey = "forecast"
        static let spendingKey = "spending"
    }

    let allowance: Double
    let forecast: Double
    let spending: Double

    init(allowance: Double,
         forecast: Double,
         spending: Double) {
        self.allowance = allowance
        self.forecast = forecast
        self.spending = spending
    }

}

extension CurrentMonthSummary: JSONConvertible {

    convenience init(json: JSON) throws {
        try self.init(allowance: json.get(Constants.allowanceKey),
                      forecast: json.get(Constants.forecastKey),
                      spending: json.get(Constants.spendingKey))
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Constants.allowanceKey, allowance)
        try json.set(Constants.forecastKey, forecast)
        try json.set(Constants.spendingKey, spending)
        return json
    }

}

extension CurrentMonthSummary: ResponseRepresentable {}
