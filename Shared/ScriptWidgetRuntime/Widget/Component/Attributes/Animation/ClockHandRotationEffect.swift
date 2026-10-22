// Replaces the former ClockHandKit-derived private bridge with public SwiftUI.
// Original bridge attribution: giljihun, ClockHandKit, MIT license.
// Source-compatible helper implemented exclusively with public SwiftUI APIs.
#if !os(macOS)
import Foundation
import SwiftUI

enum ClockHandPeriod {
    case hourHand, minuteHand, secondHand
    case custom(Double)
    var type: String {
        switch self {
        case .hourHand: "clockHour"
        case .minuteHand: "clockMinute"
        case .secondHand: "clockSecond"
        case .custom: "clock"
        }
    }
    var interval: Double { if case let .custom(value) = self { return value }; return 10 }
}
extension View {
    func clockHandRotationEffect(period: ClockHandPeriod, in timeZone: TimeZone = .current, anchor: UnitPoint = .center, referenceDate: Date? = nil) -> some View {
        ScriptWidgetAnimationFrame(referenceDate: referenceDate) { date, _ in
            self.rotationEffect(.degrees(ScriptWidgetAnimationPhase.clockAngle(type: period.type, interval: period.interval, date: date, timeZone: timeZone)), anchor: anchor)
        }
    }
}
#endif
