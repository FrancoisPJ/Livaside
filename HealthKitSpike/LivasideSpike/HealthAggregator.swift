import Foundation
import HealthKit
import SwiftData

/// Ce qu'il faut d'un échantillon pour calculer une journée. Découplé de SwiftData pour rester testable.
struct RecordValue {
    var kind: HealthRecordKind
    var start: Date
    var end: Date
    var value: Double? = nil
    var sleepStage: Int? = nil
    var sourceBundleId: String = ""
}

struct DaySummary: Equatable {
    var sleepHours: Double?
    var workoutCount = 0
    var workoutMinutes = 0.0
    var weightKg: Double?
    var bodyFatFraction: Double?
}

/// Règles de calcul de `TECHNICAL_DECISIONS.md`, en un seul endroit.
enum HealthAggregator {
    private static let asleepStages = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))

    static func summaries(of records: [RecordValue]) -> [String: DaySummary] {
        var days: [String: DaySummary] = [:]

        // Une nuit est attribuée au jour où elle se termine. L'union des intervalles évite de compter
        // deux fois les mêmes minutes quand la montre et une autre app enregistrent la même nuit.
        let sleeping = records.filter { $0.kind == .sleep && $0.sleepStage.map(asleepStages.contains) == true }
        for (key, entries) in Dictionary(grouping: sleeping, by: { LivasideDate.key(for: $0.end) }) {
            let intervals = entries.map { Interval(start: $0.start, end: $0.end) }
            days[key, default: DaySummary()].sleepHours = totalDuration(mergeIntervals(intervals)) / 3_600
        }

        // Une séance compte pour le jour où elle commence, même à cheval sur minuit.
        for workout in distinctWorkouts(records.filter { $0.kind == .workout }) {
            let key = LivasideDate.key(for: workout.start)
            days[key, default: DaySummary()].workoutCount += 1
            days[key, default: DaySummary()].workoutMinutes += workout.end.timeIntervalSince(workout.start) / 60
        }

        for (key, entries) in Dictionary(grouping: records.filter { $0.kind == .weight }, by: { LivasideDate.key(for: $0.start) }) {
            days[key, default: DaySummary()].weightKg = mean(entries.compactMap(\.value))
        }
        for (key, entries) in Dictionary(grouping: records.filter { $0.kind == .bodyFat }, by: { LivasideDate.key(for: $0.start) }) {
            days[key, default: DaySummary()].bodyFatFraction = mean(entries.compactMap(\.value))
        }
        return days
    }

    /// Deux sources différentes qui enregistrent la même séance (montre + app de course) ne comptent
    /// qu'une fois : si une séance recouvre la moitié de la précédente, on garde la plus longue.
    /// Les échantillons d'origine restent intacts dans `HealthRecord`.
    static func distinctWorkouts(_ workouts: [RecordValue]) -> [RecordValue] {
        var kept: [RecordValue] = []
        for workout in workouts.sorted(by: { $0.start < $1.start }) {
            guard let last = kept.last, last.sourceBundleId != workout.sourceBundleId else {
                kept.append(workout)
                continue
            }
            let overlap = min(last.end, workout.end).timeIntervalSince(max(last.start, workout.start))
            let shorter = min(last.end.timeIntervalSince(last.start), workout.end.timeIntervalSince(workout.start))
            if overlap > 0, overlap >= shorter / 2 {
                if workout.end.timeIntervalSince(workout.start) > last.end.timeIntervalSince(last.start) {
                    kept[kept.count - 1] = workout
                }
            } else {
                kept.append(workout)
            }
        }
        return kept
    }

    /// Recalcule les `DailyHealthSnapshot` des `days` derniers jours depuis le miroir local.
    /// Un jour sans donnée garde des valeurs nil : une absence n'est jamais un zéro.
    static func rebuildSnapshots(context: ModelContext, days: Int, now: Date = .now) throws {
        let today = LivasideDate.startOfDay(now)
        let firstDay = LivasideDate.calendar.date(byAdding: .day, value: -(days - 1), to: today)!
        // Une nuit qui finit le premier jour a commencé la veille.
        let readFrom = LivasideDate.calendar.date(byAdding: .day, value: -1, to: firstDay)!
        let records = try context.fetch(FetchDescriptor<HealthRecord>(predicate: #Predicate { $0.end >= readFrom }))
        let summaries = summaries(of: records.compactMap { record in
            HealthRecordKind(rawValue: record.kind).map {
                RecordValue(kind: $0, start: record.start, end: record.end, value: record.value,
                            sleepStage: record.sleepStage, sourceBundleId: record.sourceBundleId)
            }
        })

        var existing: [String: DailyHealthSnapshot] = [:]
        for snapshot in try context.fetch(FetchDescriptor<DailyHealthSnapshot>()) {
            existing[snapshot.dayKey] = snapshot
        }
        for offset in 0..<days {
            let day = LivasideDate.calendar.date(byAdding: .day, value: offset, to: firstDay)!
            let key = LivasideDate.key(for: day)
            let snapshot = existing[key] ?? DailyHealthSnapshot(dayKey: key, day: day)
            if snapshot.modelContext == nil { context.insert(snapshot) }
            let summary = summaries[key] ?? DaySummary()
            snapshot.sleepHours = summary.sleepHours
            snapshot.workoutCount = summary.workoutCount
            snapshot.workoutMinutes = summary.workoutMinutes
            snapshot.weightKg = summary.weightKg
            snapshot.bodyFatFraction = summary.bodyFatFraction
            snapshot.updatedAt = now
        }
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}
