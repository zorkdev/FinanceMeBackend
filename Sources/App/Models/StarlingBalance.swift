import Vapor

struct StarlingAmount: Content {
    let minorUnits: Int

    var doubleValue: Double { Double(minorUnits) / 100 }
}

struct StarlingBalance: Content {
    let effectiveBalance: StarlingAmount
}
