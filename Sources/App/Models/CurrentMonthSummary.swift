import Vapor

struct CurrentMonthSummary: Content {
    let allowance: Double
    let forecast: Double
    let spending: Double
}
