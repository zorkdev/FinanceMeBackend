import Foundation

enum Formatters {
    static let apiDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = Foundation.TimeZone(abbreviation: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter
    }()
}
