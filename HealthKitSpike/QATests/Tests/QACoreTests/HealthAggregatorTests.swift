import XCTest
import HealthKit
@testable import QACore

final class HealthAggregatorTests: XCTestCase {
    private let asleep = HKCategoryValueSleepAnalysis.asleepCore.rawValue

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.timeZone = LivasideDate.calendar.timeZone
        f.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withSpaceBetweenDateAndTime]
        return f.date(from: iso)!
    }

    /// Montre + autre app qui enregistrent la même nuit : les minutes ne sont comptées qu'une fois,
    /// et la nuit va au jour du réveil.
    func testOverlappingSleepSourcesCountOnceAndLandOnWakeDay() {
        let night = [
            RecordValue(kind: .sleep, start: date("2026-03-09 23:00:00"), end: date("2026-03-10 07:00:00"),
                        sleepStage: asleep, sourceBundleId: "watch"),
            RecordValue(kind: .sleep, start: date("2026-03-09 23:30:00"), end: date("2026-03-10 06:30:00"),
                        sleepStage: asleep, sourceBundleId: "app"),
        ]
        let days = HealthAggregator.summaries(of: night)
        XCTAssertEqual(days.keys.sorted(), ["2026-03-10"])
        XCTAssertEqual(days["2026-03-10"]?.sleepHours ?? 0, 8, accuracy: 0.001)
    }

    func testSameWorkoutFromTwoSourcesCountsOnce() {
        let workouts = [
            RecordValue(kind: .workout, start: date("2026-03-10 10:00:00"), end: date("2026-03-10 11:00:00"), sourceBundleId: "watch"),
            RecordValue(kind: .workout, start: date("2026-03-10 10:05:00"), end: date("2026-03-10 10:55:00"), sourceBundleId: "strava"),
        ]
        XCTAssertEqual(HealthAggregator.summaries(of: workouts)["2026-03-10"]?.workoutCount, 1)
    }

    func testEmptyInputGivesNoDaysRatherThanZeros() {
        XCTAssertTrue(HealthAggregator.summaries(of: []).isEmpty)
    }
}
