import Foundation
import SwiftData

@Model
final class Meal {
    var id: UUID
    var date: Date
    var name: String
    var calories: Int
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date = .now,
        name: String,
        calories: Int,
        proteinGrams: Double = 0,
        carbsGrams: Double = 0,
        fatGrams: Double = 0
    ) {
        self.id = id
        self.date = date
        self.name = name
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.createdAt = .now
        self.updatedAt = .now
    }
}

enum HealthRecordKind: String, CaseIterable {
    case sleep, workout, weight, bodyFat
}

/// Miroir local d'un échantillon Apple Health, identifié par son UUID HealthKit.
/// C'est la source de vérité locale : les agrégats journaliers en sont recalculés, et c'est
/// ce qu'un export (MCP) lira. Rien n'est fusionné ni supprimé ici, sauf si Santé le supprime.
@Model
final class HealthRecord {
    @Attribute(.unique) var uuid: UUID
    var kind: String
    var start: Date
    var end: Date
    /// kg pour le poids, fraction pour la masse grasse (`0,15` = `15 %`), nil sinon.
    var value: Double?
    /// `HKCategoryValueSleepAnalysis.rawValue` pour le sommeil.
    var sleepStage: Int?
    /// `HKWorkoutActivityType.rawValue` pour les séances.
    var activityType: UInt?
    var energyKcal: Double?
    var distanceMeters: Double?
    var sourceName: String
    var sourceBundleId: String

    init(uuid: UUID, kind: HealthRecordKind, start: Date, end: Date, sourceName: String, sourceBundleId: String) {
        self.uuid = uuid
        self.kind = kind.rawValue
        self.start = start
        self.end = end
        self.sourceName = sourceName
        self.sourceBundleId = sourceBundleId
    }
}

/// Ancre HealthKit persistée par type : la synchro suivante ne lit que les ajouts et suppressions.
@Model
final class HealthAnchor {
    @Attribute(.unique) var kind: String
    var data: Data

    init(kind: HealthRecordKind, data: Data) {
        self.kind = kind.rawValue
        self.data = data
    }
}

/// Agrégat local pour l'affichage, recalculé depuis `HealthRecord` à chaque synchronisation.
@Model
final class DailyHealthSnapshot {
    var dayKey: String
    var day: Date
    var sleepHours: Double?
    var workoutCount: Int
    var workoutMinutes: Double
    var weightKg: Double?
    var bodyFatFraction: Double?
    var updatedAt: Date

    init(dayKey: String, day: Date) {
        self.dayKey = dayKey
        self.day = day
        self.workoutCount = 0
        self.workoutMinutes = 0
        self.updatedAt = .now
    }
}

@Model
final class SyncState {
    var key: String
    var lastSuccessfulSync: Date?
    var lastError: String?

    init(key: String = "healthkit") {
        self.key = key
    }
}

enum LivasideDate {
    static let calendar = Calendar.autoupdatingCurrent

    /// Jour calendaire (`yyyy-MM-dd`) dans le fuseau *actuel* de l'utilisateur. Calculé depuis le
    /// calendrier auto-actualisé à chaque appel : un formateur statique garderait le fuseau du
    /// lancement de l'app et décalerait les jours après un voyage.
    static func key(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
    static func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }
}

enum LivasideStore {
    static let schema = Schema([Meal.self, HealthRecord.self, HealthAnchor.self, DailyHealthSnapshot.self, SyncState.self,
                                Food.self, Recipe.self, RecipeIngredient.self, FoodEntry.self, MealNote.self])

    /// Jamais iCloud : les données de santé ne quittent pas l'iPhone (guideline 5.1.3(ii), LIV-5).
    /// SwiftData activerait CloudKit tout seul si un entitlement iCloud apparaissait sur le target.
    static let localConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)

    /// Ouvre le stockage local. S'il est illisible (migration ratée d'une ancienne version), il est mis
    /// de côté plutôt que supprimé, et l'app repart d'un stockage neuf au lieu de planter au lancement.
    /// Santé se réimporte ; seuls les repas restent dans la copie mise de côté.
    static func openLocalContainer() -> ModelContainer {
        if let container = try? ModelContainer(for: schema, configurations: localConfiguration) {
            return container
        }
        let storeURL = localConfiguration.url
        let suffix = "unreadable-\(Int(Date.now.timeIntervalSince1970))"
        for extensionSuffix in ["", "-shm", "-wal"] {
            let file = URL(fileURLWithPath: storeURL.path + extensionSuffix)
            try? FileManager.default.moveItem(at: file, to: file.appendingPathExtension(suffix))
        }
        do {
            return try ModelContainer(for: schema, configurations: localConfiguration)
        } catch {
            fatalError("Impossible d'ouvrir le stockage local Livaside : \(error.localizedDescription)")
        }
    }
}
