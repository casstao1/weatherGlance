import Foundation

enum HourLabelFormatter {

    /// Returns "Now" for the current hour, or "10A" / "2P" style for future hours.
    static func compactHourLabel(for date: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, equalTo: now, toGranularity: .hour) {
            return "Now"
        }
        let hour = calendar.component(.hour, from: date)
        let suffix = hour < 12 ? "A" : "P"
        let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(hour12)\(suffix)"
    }

    /// Builds "Now + next N hours" labels.
    static func labels(from startDate: Date, count: Int, calendar: Calendar = .current) -> [String] {
        (0..<count).map { offset in
            guard let date = calendar.date(byAdding: .hour, value: offset, to: startDate) else {
                return "--"
            }
            return compactHourLabel(for: date, now: startDate, calendar: calendar)
        }
    }
}
