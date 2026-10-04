import Foundation
import HealthKit
import SwiftData

/// Données fictives pour montrer l'app sans exposer la santé du fondateur.
/// Stockage en mémoire, régénéré à chaque activation : la démo repart toujours du même état
/// et ne touche jamais aux vraies données. Les agrégats passent par le même calcul que Santé.
enum DemoData {
    static let days = 35

    @MainActor static func makeContainer(now: Date = .now) throws -> ModelContainer {
        let container = try ModelContainer(for: LivasideStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        seed(into: context, now: now)
        try HealthAggregator.rebuildSnapshots(context: context, days: days, now: now)
        let state = SyncState()
        state.lastSuccessfulSync = now
        context.insert(state)
        try context.save()
        return container
    }

    static func seed(into context: ModelContext, now: Date) {
        var random = SeededRandom(seed: 42)
        let today = LivasideDate.startOfDay(now)

        for daysAgo in 0..<days {
            let day = LivasideDate.calendar.date(byAdding: .day, value: -daysAgo, to: today)!

            // Nuit qui se termine ce matin, sauf deux nuits sans montre : le trou doit se voir.
            if daysAgo != 9 && daysAgo != 20 {
                let wake = day.addingTimeInterval(6.75 * 3_600 + random.next(in: 0...3_600))
                let asleep = random.next(in: 6.3...8.1) * 3_600
                insert(.sleep, start: wake.addingTimeInterval(-asleep), end: wake, into: context) {
                    $0.sleepStage = HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                }
            }

            // Une pesée tous les deux jours environ, avec une légère baisse sur la période.
            if daysAgo % 2 == 0 || daysAgo % 7 == 3 {
                let weighIn = day.addingTimeInterval(7.5 * 3_600)
                if weighIn <= now {
                    insert(.weight, start: weighIn, end: weighIn, into: context) {
                        $0.value = 77.2 + Double(daysAgo) * 0.04 + random.next(in: -0.3...0.3)
                    }
                    insert(.bodyFat, start: weighIn, end: weighIn, into: context) {
                        $0.value = 0.17 + Double(daysAgo) * 0.0003 + random.next(in: -0.004...0.004)
                    }
                }
            }

            // Quatre séances par semaine, dont une ce matin.
            let weekday = LivasideDate.calendar.component(.weekday, from: day)
            if daysAgo == 0 || [2, 4, 6, 7].contains(weekday) {
                let start = day.addingTimeInterval(daysAgo == 0 ? 6.5 * 3_600 : random.next(in: 17...19) * 3_600)
                let end = start.addingTimeInterval(random.next(in: 35...70) * 60)
                if end <= now {
                    insert(.workout, start: start, end: end, into: context) {
                        $0.activityType = (weekday == 7 ? HKWorkoutActivityType.running : .traditionalStrengthTraining).rawValue
                        $0.energyKcal = end.timeIntervalSince(start) / 60 * 7
                    }
                }
            }
        }

        let meals: [(hour: Double, name: String, kcal: Int, protein: Double, carbs: Double, fat: Double)] = [
            (7.75, "Skyr, granola et banane", 420, 28, 58, 9),
            (12.5, "Bowl poulet, riz et légumes", 640, 45, 72, 16),
            (16.25, "Pomme et amandes", 230, 6, 22, 14),
        ]
        for meal in meals {
            let date = today.addingTimeInterval(meal.hour * 3_600)
            // Le petit-déjeuner reste visible même si la démo commence tôt : jamais d'écran vide.
            guard date <= now || meal.hour == meals[0].hour else { continue }
            context.insert(Meal(date: date, name: meal.name, calories: meal.kcal,
                                proteinGrams: meal.protein, carbsGrams: meal.carbs, fatGrams: meal.fat))
        }
    }

    private static func insert(_ kind: HealthRecordKind, start: Date, end: Date, into context: ModelContext,
                               configure: (HealthRecord) -> Void) {
        let record = HealthRecord(uuid: UUID(), kind: kind, start: start, end: end,
                                  sourceName: "Démo Livaside", sourceBundleId: "com.livaside.demo")
        configure(record)
        context.insert(record)
    }
}

/// Générateur reproductible : la même démo à chaque fois, sans surprise devant quelqu'un.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let unit = Double(state >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}
