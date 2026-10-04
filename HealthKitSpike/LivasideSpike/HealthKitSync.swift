import Foundation
import HealthKit
import SwiftData

/// Importe Apple Health dans le miroir local (`HealthRecord`) : une requête ancrée par type ne lit
/// que les ajouts et suppressions depuis la dernière fois, puis les agrégats sont recalculés.
/// Écrit toujours dans le stockage réel, jamais dans celui du mode démo.
@MainActor
final class HealthKitSync: ObservableObject {
    /// Couvre les 30 jours des tendances et laisse de la marge pour un poids mesuré rarement.
    static let windowDays = 90

    @Published private(set) var isSyncing = false
    /// Message à afficher seulement quand quelque chose demande l'attention de l'utilisateur.
    @Published private(set) var problem: String?

    private let container: ModelContainer
    private let store = HKHealthStore()
    private var needsAnotherPass = false
    private var isObserving = false

    init(container: ModelContainer) {
        self.container = container
    }

    private static func sampleType(_ kind: HealthRecordKind) -> HKSampleType {
        switch kind {
        case .sleep: HKCategoryType(.sleepAnalysis)
        case .workout: HKWorkoutType.workoutType()
        case .weight: HKQuantityType(.bodyMass)
        case .bodyFat: HKQuantityType(.bodyFatPercentage)
        }
    }

    private static var readTypes: Set<HKObjectType> { Set(HealthRecordKind.allCases.map(sampleType)) }

    func synchronize() async {
        guard !isSyncing else {
            needsAnotherPass = true
            return
        }
        guard HKHealthStore.isHealthDataAvailable() else {
            problem = "Apple Health n’est pas disponible sur cet appareil"
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        let context = container.mainContext
        do {
            // On ne peut pas savoir si la lecture est autorisée : on demande une fois, puis un
            // résultat vide se lit comme « aucune donnée ou accès à vérifier ».
            if try await store.statusForAuthorizationRequest(toShare: [], read: Self.readTypes) == .shouldRequest {
                try await store.requestAuthorization(toShare: [], read: Self.readTypes)
            }
            startObserving()

            repeat {
                needsAnotherPass = false
                for kind in HealthRecordKind.allCases {
                    try await importChanges(of: kind, into: context)
                }
            } while needsAnotherPass

            try HealthAggregator.rebuildSnapshots(context: context, days: Self.windowDays)
            let state = try syncState(in: context)
            state.lastSuccessfulSync = .now
            state.lastError = nil
            try context.save()
            problem = nil
        } catch let error as HKError where error.code == .errorDatabaseInaccessible {
            // iPhone verrouillé pendant une livraison en arrière-plan : la prochaine ouverture rattrapera.
        } catch {
            problem = "Synchronisation à vérifier : \(error.localizedDescription)"
            if let state = try? syncState(in: context) {
                state.lastError = error.localizedDescription
                try? context.save()
            }
        }
    }

    /// À l'ouverture de l'app, y compris quand HealthKit la réveille en arrière-plan.
    func startObservingIfAlreadyAuthorized() async {
        guard HKHealthStore.isHealthDataAvailable(),
              (try? await store.statusForAuthorizationRequest(toShare: [], read: Self.readTypes)) == .unnecessary
        else { return }
        startObserving()
    }

    /// Réveille l'app quand Santé reçoit de nouvelles données. HealthKit décide du moment :
    /// l'interface affiche la dernière synchro et ne promet pas de temps réel.
    private func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        for kind in HealthRecordKind.allCases {
            let type = Self.sampleType(kind)
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                guard error == nil else {
                    completion()
                    return
                }
                Task { @MainActor in
                    await self?.synchronize()
                    completion()
                }
            }
            store.execute(query)
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
        }
    }

    private func importChanges(of kind: HealthRecordKind, into context: ModelContext) async throws {
        let key = kind.rawValue
        let savedAnchor = try context.fetch(FetchDescriptor<HealthAnchor>(predicate: #Predicate { $0.kind == key })).first
        let anchor = savedAnchor.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0.data) }

        let windowStart = LivasideDate.calendar.date(byAdding: .day, value: -Self.windowDays, to: .now)!
        let query = HKAnchoredObjectQueryDescriptor(
            predicates: [.sample(type: Self.sampleType(kind), predicate: HKQuery.predicateForSamples(withStart: windowStart, end: nil))],
            anchor: anchor
        )
        let result = try await query.result(for: store)

        let existing = try context.fetch(FetchDescriptor<HealthRecord>(predicate: #Predicate { $0.kind == key }))
        var byID = Dictionary(existing.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        for deleted in result.deletedObjects {
            if let record = byID.removeValue(forKey: deleted.uuid) { context.delete(record) }
        }
        for sample in result.addedSamples where byID[sample.uuid] == nil {
            let record = Self.record(from: sample, kind: kind)
            context.insert(record)
            byID[sample.uuid] = record
        }

        let anchorData = try NSKeyedArchiver.archivedData(withRootObject: result.newAnchor, requiringSecureCoding: true)
        if let savedAnchor {
            savedAnchor.data = anchorData
        } else {
            context.insert(HealthAnchor(kind: kind, data: anchorData))
        }
    }

    private static func record(from sample: HKSample, kind: HealthRecordKind) -> HealthRecord {
        let source = sample.sourceRevision.source
        let record = HealthRecord(uuid: sample.uuid, kind: kind, start: sample.startDate, end: sample.endDate,
                                  sourceName: source.name, sourceBundleId: source.bundleIdentifier)
        switch kind {
        case .sleep:
            record.sleepStage = (sample as? HKCategorySample)?.value
        case .workout:
            guard let workout = sample as? HKWorkout else { break }
            record.activityType = workout.workoutActivityType.rawValue
            record.energyKcal = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie())
            record.distanceMeters = [HKQuantityType(.distanceWalkingRunning), HKQuantityType(.distanceCycling), HKQuantityType(.distanceSwimming)]
                .lazy.compactMap { workout.statistics(for: $0)?.sumQuantity()?.doubleValue(for: .meter()) }.first
        case .weight:
            record.value = (sample as? HKQuantitySample)?.quantity.doubleValue(for: .gramUnit(with: .kilo))
        case .bodyFat:
            record.value = (sample as? HKQuantitySample)?.quantity.doubleValue(for: .percent())
        }
        return record
    }

    private func syncState(in context: ModelContext) throws -> SyncState {
        if let state = try context.fetch(FetchDescriptor<SyncState>(predicate: #Predicate { $0.key == "healthkit" })).first {
            return state
        }
        let state = SyncState()
        context.insert(state)
        return state
    }
}
