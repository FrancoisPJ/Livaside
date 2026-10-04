import Foundation
import HealthKit

/// Modèle matériel exact (ex. « iPhone17,2 ») — plus utile qu'« iPhone » dans un rapport,
/// et lisible hors du thread principal, contrairement à `UIDevice.current`.
private func hardwareModel() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machine = withUnsafeBytes(of: &systemInfo.machine) { buffer in
        String(cString: buffer.baseAddress!.assumingMemoryBound(to: CChar.self))
    }
    return machine
}

/// Moteur du spike. Chaque `probe*` renvoie une section de rapport et n'échoue jamais
/// bruyamment : une erreur devient une section `.fail` avec le message.
final class HealthKitProbe {

    let store = HKHealthStore()

    // MARK: Types lus

    let sleepType = HKCategoryType(.sleepAnalysis)
    let workoutType = HKWorkoutType.workoutType()

    var bodyQuantityTypes: [(String, HKQuantityType, HKUnit)] {
        [
            ("Poids", HKQuantityType(.bodyMass), .gramUnit(with: .kilo)),
            ("Masse grasse", HKQuantityType(.bodyFatPercentage), .percent()),
            ("Masse maigre", HKQuantityType(.leanBodyMass), .gramUnit(with: .kilo)),
            ("Taille", HKQuantityType(.height), .meterUnit(with: .centi)),
        ]
    }

    var activityQuantityTypes: [(String, HKQuantityType, HKUnit)] {
        [
            ("Énergie active", HKQuantityType(.activeEnergyBurned), .kilocalorie()),
            ("Distance marche/course", HKQuantityType(.distanceWalkingRunning), .meter()),
            ("Fréquence cardiaque repos", HKQuantityType(.restingHeartRate), HKUnit.count().unitDivided(by: .minute())),
            ("VFC (SDNN)", HKQuantityType(.heartRateVariabilitySDNN), .secondUnit(with: .milli)),
        ]
    }

    /// Liste close des types demandés en v1 — § 2.1.2 de la base privacy (LIV-5).
    /// Hors périmètre volontairement : les types nutrition (saisie manuelle en v1), les
    /// caractéristiques (`dateOfBirth`, `biologicalSex`), `stepCount`, `waistCircumference`,
    /// `bodyMassIndex` et tout `HKClinicalType`.
    /// Ne rien ajouter ici sans en informer Privacy & Compliance : la feuille d'autorisation
    /// ne s'affiche qu'une fois par ensemble de types.
    var allReadTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [sleepType, workoutType]
        for (_, t, _) in bodyQuantityTypes { types.insert(t) }
        for (_, t, _) in activityQuantityTypes { types.insert(t) }
        return types
    }

    /// L'app n'écrit rien dans Santé en v1 : lecture seule (§ 2.1.2).
    /// `NSHealthUpdateUsageDescription` n'est donc pas déclarée, et demander une écriture
    /// sans cette clé fait planter `requestAuthorization`.
    var allWriteTypes: Set<HKSampleType> { [] }

    // MARK: - 1. Autorisation

    func probeAuthorization() async -> ReportSection {
        let clock = Date()
        var s = ReportSection(title: "1. Flux d'autorisation", verdict: .ok)

        s.lines.append(.init(label: "HealthKit disponible", value: HKHealthStore.isHealthDataAvailable() ? "oui" : "NON"))
        guard HKHealthStore.isHealthDataAvailable() else {
            s.verdict = .fail
            s.findings.append("HealthKit indisponible sur cet appareil : rien d'autre ne peut être testé.")
            s.elapsedMs = Int(Date().timeIntervalSince(clock) * 1000)
            return s
        }

        // Avant la demande : seule API fiable pour savoir s'il faut afficher la feuille.
        do {
            let status = try await store.statusForAuthorizationRequest(toShare: allWriteTypes, read: allReadTypes)
            let label: String
            switch status {
            case .shouldRequest: label = "shouldRequest (feuille à afficher)"
            case .unnecessary: label = "unnecessary (déjà demandé)"
            case .unknown: label = "unknown"
            @unknown default: label = "inconnu"
            }
            s.lines.append(.init(label: "statusForAuthorizationRequest (avant)", value: label))
        } catch {
            s.lines.append(.init(label: "statusForAuthorizationRequest (avant)", value: "erreur : \(error.localizedDescription)"))
        }

        // La demande elle-même.
        do {
            try await store.requestAuthorization(toShare: allWriteTypes, read: allReadTypes)
            s.lines.append(.init(label: "requestAuthorization", value: "retourné sans erreur"))
        } catch {
            s.verdict = .fail
            s.lines.append(.init(label: "requestAuthorization", value: "ERREUR : \(error.localizedDescription)"))
            s.findings.append("La demande d'autorisation a échoué — vérifier l'entitlement HealthKit et les clés NSHealth*UsageDescription.")
            s.elapsedMs = Int(Date().timeIntervalSince(clock) * 1000)
            return s
        }

        // Après la demande : ce que l'API avoue sur les types en LECTURE.
        var notDetermined = 0
        var denied = 0
        var authorized = 0
        for type in allReadTypes.sorted(by: { $0.identifier < $1.identifier }) {
            switch store.authorizationStatus(for: type) {
            case .notDetermined: notDetermined += 1
            case .sharingDenied: denied += 1
            case .sharingAuthorized: authorized += 1
            @unknown default: break
            }
        }
        s.lines.append(.init(label: "Types lus — statut notDetermined", value: "\(notDetermined)"))
        s.lines.append(.init(label: "Types lus — statut sharingDenied", value: "\(denied)"))
        s.lines.append(.init(label: "Types lus — statut sharingAuthorized", value: "\(authorized)"))

        s.lines.append(.init(label: "Types demandés en écriture", value: "aucun (lecture seule en v1)"))

        do {
            let status = try await store.statusForAuthorizationRequest(toShare: allWriteTypes, read: allReadTypes)
            s.lines.append(.init(label: "statusForAuthorizationRequest (après)", value: status == .unnecessary ? "unnecessary" : "shouldRequest"))
        } catch {
            s.lines.append(.init(label: "statusForAuthorizationRequest (après)", value: "erreur"))
        }

        // Caractéristiques (date de naissance, sexe) : volontairement non demandées en v1
        // (§ 2.1.2). Aucun calcul de l'app ne les exige aujourd'hui.
        s.lines.append(.init(label: "Caractéristiques demandées", value: "aucune (hors périmètre v1)"))

        if denied > 0 || notDetermined > 0 {
            s.verdict = .warn
            s.findings.append("`authorizationStatus(for:)` ne dit JAMAIS si la lecture est accordée : Apple masque le refus pour ne pas le révéler à l'app. Un type lu reste `notDetermined`/`sharingDenied` même quand les données arrivent. Conséquence : impossible d'afficher « Santé non connectée » sur la base du statut — il faut déduire l'état réel du fait qu'une requête renvoie ou non des données.")
        }
        s.findings.append("`statusForAuthorizationRequest` est la seule API fiable pour décider d'afficher la feuille d'autorisation (évite de la re-proposer à chaque lancement).")
        s.findings.append("La feuille ne s'affiche qu'UNE fois par ensemble de types. Ajouter un type plus tard = nouvelle demande ; l'utilisateur doit ré-autoriser. Conséquence : déclarer dès la v1 tous les types qu'on prévoit de lire.")

        s.elapsedMs = Int(Date().timeIntervalSince(clock) * 1000)
        return s
    }

    // MARK: - 2. Sommeil

    struct SleepRecord {
        var start: Date
        var end: Date
        var value: Int
        var sourceName: String
        var bundleID: String
        var deviceName: String
        var duration: TimeInterval { end.timeIntervalSince(start) }

        var phaseLabel: String {
            switch HKCategoryValueSleepAnalysis(rawValue: value) {
            case .inBed: return "inBed"
            case .asleepUnspecified: return "asleepUnspecified"
            case .awake: return "awake"
            case .asleepCore: return "asleepCore"
            case .asleepDeep: return "asleepDeep"
            case .asleepREM: return "asleepREM"
            default: return "valeur inconnue (\(value))"
            }
        }

        var isAsleep: Bool {
            guard let v = HKCategoryValueSleepAnalysis(rawValue: value) else { return false }
            return HKCategoryValueSleepAnalysis.allAsleepValues.contains(v)
        }

        var isInBed: Bool { value == HKCategoryValueSleepAnalysis.inBed.rawValue }
        var hasPhaseDetail: Bool {
            let v = HKCategoryValueSleepAnalysis(rawValue: value)
            return v == .asleepCore || v == .asleepDeep || v == .asleepREM
        }
    }

    func fetchSleep(days: Int) async throws -> [SleepRecord] {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = try await descriptor.result(for: store)
        return samples.map {
            SleepRecord(
                start: $0.startDate,
                end: $0.endDate,
                value: $0.value,
                sourceName: $0.sourceRevision.source.name,
                bundleID: $0.sourceRevision.source.bundleIdentifier,
                deviceName: $0.device?.name ?? $0.sourceRevision.productType ?? "—"
            )
        }
    }

    /// Découpe les échantillons en nuits : nouvelle nuit dès qu'un trou > `gapHours` apparaît.
    func sleepSessions(_ records: [SleepRecord], gapHours: Double = 3) -> [[SleepRecord]] {
        guard !records.isEmpty else { return [] }
        let sorted = records.sorted { $0.start < $1.start }
        var sessions: [[SleepRecord]] = []
        var current: [SleepRecord] = [sorted[0]]
        var currentEnd = sorted[0].end
        for r in sorted.dropFirst() {
            if r.start.timeIntervalSince(currentEnd) > gapHours * 3600 {
                sessions.append(current)
                current = [r]
                currentEnd = r.end
            } else {
                current.append(r)
                currentEnd = max(currentEnd, r.end)
            }
        }
        sessions.append(current)
        return sessions
    }

    func probeSleep() async -> ReportSection {
        let clock = Date()
        var s = ReportSection(title: "2. Sommeil (durée, phases, sources)", verdict: .ok)
        let days = 60

        let records: [SleepRecord]
        do {
            records = try await fetchSleep(days: days)
        } catch {
            s.verdict = .fail
            s.lines.append(.init(label: "Requête sommeil", value: "ERREUR : \(error.localizedDescription)"))
            s.elapsedMs = Int(Date().timeIntervalSince(clock) * 1000)
            return s
        }

        s.lines.append(.init(label: "Fenêtre interrogée", value: "\(days) jours"))
        s.lines.append(.init(label: "Échantillons bruts", value: "\(records.count)"))

        guard !records.isEmpty else {
            s.verdict = .fail
            s.findings.append("Aucun échantillon de sommeil : soit la lecture a été refusée, soit aucune source n'écrit de sommeil. À distinguer AVANT de conclure (voir section autorisation).")
            s.elapsedMs = Int(Date().timeIntervalSince(clock) * 1000)
            return s
        }

        // Sources
        var bySource: [String: [SleepRecord]] = [:]
        for r in records { bySource["\(r.sourceName) [\(r.bundleID)]", default: []].append(r) }
        s.lines.append(.init(label: "Sources distinctes", value: "\(bySource.count)"))
        for (key, rs) in bySource.sorted(by: { $0.value.count > $1.value.count }) {
            let phases = Set(rs.map(\.phaseLabel)).sorted().joined(separator: ", ")
            s.lines.append(.init(label: "— \(key)", value: "\(rs.count) éch. · \(phases)"))
        }

        // Valeurs rencontrées
        var byPhase: [String: (count: Int, total: TimeInterval)] = [:]
        for r in records {
            var e = byPhase[r.phaseLabel] ?? (0, 0)
            e.count += 1
            e.total += r.duration
            byPhase[r.phaseLabel] = e
        }
        for (phase, e) in byPhase.sorted(by: { $0.value.total > $1.value.total }) {
            s.lines.append(.init(label: "Phase \(phase)", value: "\(e.count) éch. · cumul \(fmtDuration(e.total))"))
        }

        // Granularité : un échantillon de phase Apple Watch dure quelques minutes.
        let asleepRecords = records.filter(\.isAsleep)
        if !asleepRecords.isEmpty {
            let durations = asleepRecords.map(\.duration).sorted()
            let median = durations[durations.count / 2]
            s.lines.append(.init(label: "Durée médiane d'un échantillon « endormi »", value: fmtDuration(median)))
        }

        // Nuits
        let sessions = sleepSessions(records)
        s.lines.append(.init(label: "Nuits détectées (trou > 3 h)", value: "\(sessions.count)"))

        var nightsWithPhases = 0
        var nightsInBedOnly = 0
        var nightsMultiSource = 0
        var worstDoubleCountRatio = 1.0
        var worstNightLabel = "—"
        var totalNaive: TimeInterval = 0
        var totalMerged: TimeInterval = 0
        var detailLines: [ReportLine] = []

        for session in sessions {
            let asleep = session.filter(\.isAsleep)
            let intervals = asleep.map { Interval(start: $0.start, end: $0.end) }
            let naive = intervals.reduce(0) { $0 + $1.duration }
            let merged = totalDuration(mergeIntervals(intervals))
            totalNaive += naive
            totalMerged += merged

            let sources = Set(session.map(\.bundleID))
            if sources.count > 1 { nightsMultiSource += 1 }
            if session.contains(where: \.hasPhaseDetail) {
                nightsWithPhases += 1
            } else if session.allSatisfy({ $0.isInBed || $0.phaseLabel == "asleepUnspecified" }) {
                nightsInBedOnly += 1
            }

            if merged > 0, naive / merged > worstDoubleCountRatio {
                worstDoubleCountRatio = naive / merged
                worstNightLabel = fmtDay(session.first?.start)
            }

            if detailLines.count < 10 {
                let night = fmtDay(session.last?.end)
                let inBedIntervals = session.filter(\.isInBed).map { Interval(start: $0.start, end: $0.end) }
                let inBed = totalDuration(mergeIntervals(inBedIntervals))
                var phaseBits: [String] = []
                for phase in ["asleepDeep", "asleepREM", "asleepCore", "asleepUnspecified", "awake"] {
                    let d = totalDuration(mergeIntervals(session.filter { $0.phaseLabel == phase }.map { Interval(start: $0.start, end: $0.end) }))
                    if d > 0 { phaseBits.append("\(phase.replacingOccurrences(of: "asleep", with: "")) \(fmtDuration(d))") }
                }
                detailLines.append(.init(
                    label: "Nuit du \(night)",
                    value: "endormi \(fmtDuration(merged)) (somme brute \(fmtDuration(naive))) · au lit \(fmtDuration(inBed)) · \(sources.count) source(s) · \(phaseBits.joined(separator: ", "))"
                ))
            }
        }

        s.lines.append(.init(label: "Nuits avec phases détaillées", value: "\(nightsWithPhases)/\(sessions.count)"))
        s.lines.append(.init(label: "Nuits sans phases (inBed / unspecified)", value: "\(nightsInBedOnly)/\(sessions.count)"))
        s.lines.append(.init(label: "Nuits avec plusieurs sources", value: "\(nightsMultiSource)/\(sessions.count)"))
        s.lines.append(.init(label: "Chevauchements d'échantillons « endormi »", value: "\(overlappingPairCount(records.filter(\.isAsleep).map { Interval(start: $0.start, end: $0.end) })) paires"))
        s.lines.append(.init(label: "Cumul « endormi » somme brute", value: fmtDuration(totalNaive)))
        s.lines.append(.init(label: "Cumul « endormi » après fusion", value: fmtDuration(totalMerged)))
        if totalMerged > 0 {
            let err = (totalNaive / totalMerged - 1) * 100
            s.lines.append(.init(label: "Écart somme brute vs fusion", value: "+\(fmtNumber(err)) %"))
            if err > 1 {
                s.verdict = .warn
                s.findings.append("Additionner naïvement les échantillons surestime le sommeil de \(fmtNumber(err)) % sur la période (pire nuit : ×\(fmtNumber(worstDoubleCountRatio, 2)) le \(worstNightLabel)). Toute durée affichée doit passer par une fusion d'intervalles.")
            }
        }
        s.lines.append(contentsOf: detailLines)

        s.findings.append("Le sommeil arrive en MORCEAUX, pas en une ligne par nuit : il faut regrouper soi-même les échantillons en nuits (règle du trou > 3 h) et stocker la nuit agrégée, pas l'échantillon brut.")
        s.findings.append("`inBed` et les phases `asleep*` se recouvrent par construction : « temps au lit » et « temps endormi » sont deux mesures différentes, à ne jamais additionner.")
        if nightsWithPhases < sessions.count {
            s.findings.append("Les phases ne sont présentes que les nuits où la montre est portée (\(nightsWithPhases) nuits sur \(sessions.count) ici). Le graphique de phases doit donc gérer un état « pas de détail cette nuit » — ce n'est pas un bug, c'est le cas normal.")
        }
        s.elapsedMs = Int(Date().timeIntervalSince(clock) * 1000)
        return s
    }

    // MARK: - 3. Séances

    func probeWorkouts() async -> ReportSection {
        let clock = Date()
        var s = ReportSection(title: "3. Séances d'entraînement", verdict: .ok)
        let days = 90
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        let workouts: [HKWorkout]
        do {
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.workout(predicate)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
            )
            workouts = try await descriptor.result(for: store)
        } catch {
            s.verdict = .fail
            s.lines.append(.init(label: "Requête séances", value: "ERREUR : \(error.localizedDescription)"))
            s.elapsedMs = Int(Date().timeIntervalSince(clock) * 1000)
            return s
        }

        s.lines.append(.init(label: "Fenêtre interrogée", value: "\(days) jours"))
        s.lines.append(.init(label: "Séances", value: "\(workouts.count)"))

        guard !workouts.isEmpty else {
            s.verdict = .warn
            s.findings.append("Aucune séance sur \(days) jours : l'écran « Aujourd'hui » doit avoir un état vide crédible.")
            s.elapsedMs = Int(Date().timeIntervalSince(clock) * 1000)
            return s
        }

        var bySource: [String: Int] = [:]
        for w in workouts { bySource["\(w.sourceRevision.source.name) [\(w.sourceRevision.source.bundleIdentifier)]", default: 0] += 1 }
        s.lines.append(.init(label: "Sources distinctes", value: "\(bySource.count)"))
        for (k, v) in bySource.sorted(by: { $0.value > $1.value }) {
            s.lines.append(.init(label: "— \(k)", value: "\(v) séance(s)"))
        }

        var byType: [String: Int] = [:]
        for w in workouts { byType[String(describing: w.workoutActivityType.rawValue), default: 0] += 1 }
        s.lines.append(.init(label: "Types d'activité distincts", value: "\(byType.count)"))

        // Doublons probables : même créneau, sources différentes.
        var duplicatePairs = 0
        var duplicateExamples: [String] = []
        for i in workouts.indices {
            for j in workouts.index(after: i)..<workouts.endIndex {
                let a = workouts[i], b = workouts[j]
                guard a.sourceRevision.source.bundleIdentifier != b.sourceRevision.source.bundleIdentifier else { continue }
                let startGap = abs(a.startDate.timeIntervalSince(b.startDate))
                let overlaps = a.startDate < b.endDate && b.startDate < a.endDate
                if startGap < 300 || overlaps {
                    duplicatePairs += 1
                    if duplicateExamples.count < 3 {
                        duplicateExamples.append("\(fmtDate(a.startDate)) : \(a.sourceRevision.source.name) vs \(b.sourceRevision.source.name)")
                    }
                }
            }
        }
        s.lines.append(.init(label: "Paires de séances en doublon probable", value: "\(duplicatePairs)"))
        for ex in duplicateExamples { s.lines.append(.init(label: "— exemple", value: ex)) }

        // Détail des 8 dernières + énergie/distance via statistics (API non dépréciée).
        var energyMissing = 0
        var distanceMissing = 0
        for w in workouts.prefix(8) {
            let energy = w.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
            let distance = w.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter())
            if energy == nil { energyMissing += 1 }
            if distance == nil { distanceMissing += 1 }
            var bits = ["\(fmtDuration(w.duration))"]
            bits.append(energy.map { "\(Int($0)) kcal" } ?? "kcal absent")
            if let distance { bits.append("\(fmtNumber(distance / 1000, 2)) km") }
            bits.append(w.sourceRevision.source.name)
            if w.metadata?[HKMetadataKeyIndoorWorkout] as? Bool == true { bits.append("intérieur") }
            s.lines.append(.init(label: "Séance \(fmtDate(w.startDate)) (type \(w.workoutActivityType.rawValue))", value: bits.joined(separator: " · ")))
        }
        s.lines.append(.init(label: "Énergie absente (8 dernières)", value: "\(energyMissing)/\(min(8, workouts.count))"))
        s.lines.append(.init(label: "Distance absente (8 dernières)", value: "\(distanceMissing)/\(min(8, workouts.count))"))

        s.findings.append("Les séances arrivent bien avec type, durée, source et métadonnées. L'énergie et la distance passent par `workout.statistics(for:)` (les propriétés `totalEnergyBurned`/`totalDistance` sont dépréciées depuis iOS 18) et peuvent être absentes selon la source.")
        if duplicatePairs > 0 {
            s.verdict = .warn
            s.findings.append("\(duplicatePairs) paire(s) de séances se chevauchent entre sources différentes (typiquement Apple Watch + une app tierce). Sans déduplication, le total hebdomadaire est faux. Règle retenue : à créneau égal, garder la source prioritaire (Watch) et masquer les autres, sans les supprimer.")
        }
        s.findings.append("`workoutActivityType` est un enum à ~80 valeurs : prévoir une table de libellés français + un fallback « Autre » plutôt qu'un switch exhaustif.")
        s.elapsedMs = Int(Date().timeIntervalSince(clock) * 1000)
        return s
    }

    // MARK: - 4. Poids et mesures corporelles

    func probeBody() async -> ReportSection {
        let clock = Date()
        var s = ReportSection(title: "4. Poids et mesures corporelles", verdict: .ok)
        let days = 365
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        var anyData = false
        var multiSourceTypes: [String] = []
        var sameDayMultiple = 0

        for (label, type, unit) in bodyQuantityTypes {
            do {
                let descriptor = HKSampleQueryDescriptor(
                    predicates: [.quantitySample(type: type, predicate: predicate)],
                    sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
                )
                let samples = try await descriptor.result(for: store)
                guard !samples.isEmpty else {
                    s.lines.append(.init(label: label, value: "aucun échantillon sur \(days) j"))
                    continue
                }
                anyData = true
                let sources = Set(samples.map { "\($0.sourceRevision.source.name)" })
                if sources.count > 1 { multiSourceTypes.append(label) }
                let latest = samples[0]
                let value = latest.quantity.doubleValue(for: unit)
                // HealthKit expose un pourcentage sous forme de fraction : 0,15 = 15 %.
                // Ne pas afficher la valeur canonique brute avec le symbole %, sinon la
                // mesure est divisée par 100 pour l'utilisateur.
                let displayValue: String
                if type == HKQuantityType(.bodyFatPercentage) {
                    displayValue = "\(fmtNumber(value * 100, 2)) %"
                } else {
                    displayValue = "\(fmtNumber(value, 2)) \(unit.unitString)"
                }

                // Plusieurs mesures le même jour ? (pèse-personne connectée = plusieurs par jour)
                var byDay: [Date: Int] = [:]
                for sample in samples {
                    let day = Calendar.current.startOfDay(for: sample.startDate)
                    byDay[day, default: 0] += 1
                }
                let daysWithMultiple = byDay.values.filter { $0 > 1 }.count
                sameDayMultiple += daysWithMultiple

                s.lines.append(.init(
                    label: label,
                    value: "\(samples.count) éch. · dernier \(displayValue) le \(fmtDate(latest.startDate)) · sources : \(sources.sorted().joined(separator: ", ")) · \(daysWithMultiple) jour(s) à mesures multiples"
                ))
            } catch {
                s.lines.append(.init(label: label, value: "ERREUR : \(error.localizedDescription)"))
            }
        }

        if !anyData {
            s.verdict = .warn
            s.findings.append("Aucune mesure corporelle sur un an : l'écran Tendances doit gérer l'absence totale de poids, et l'app doit proposer la saisie manuelle dès le premier lancement.")
        }
        if !multiSourceTypes.isEmpty {
            s.verdict = .warn
            s.findings.append("Mesures écrites par plusieurs sources (\(multiSourceTypes.joined(separator: ", "))). Pour le poids, afficher une moyenne par jour plutôt que « la dernière valeur » : sinon la valeur affichée saute selon la source qui a écrit en dernier.")
        }
        if sameDayMultiple > 0 {
            s.findings.append("\(sameDayMultiple) jour(s) comportent plusieurs mesures. Le modèle de données doit stocker les échantillons tels quels et agréger à l'affichage — pas « une ligne par jour » en base.")
        }
        s.findings.append("Les unités ne sont jamais implicites : HealthKit stocke des quantités, pas des kilos. Toute lecture doit nommer son `HKUnit` (`.gramUnit(with: .kilo)` ici) ; l'affichage suit la locale, le stockage reste en unité canonique. Attention : `.percent()` renvoie une fraction (`0,15` = `15 %`).")
        s.elapsedMs = Int(Date().timeIntervalSince(clock) * 1000)
        return s
    }

    // MARK: - 5. Statistiques agrégées (écran Tendances)

    func probeStatistics() async -> ReportSection {
        let clock = Date()
        var s = ReportSection(title: "5. Agrégats pour les tendances (7 / 30 jours)", verdict: .ok)
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Calendar.current.startOfDay(for: end))!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        for (label, type, unit) in activityQuantityTypes {
            let isCumulative = type.aggregationStyle == .cumulative
            do {
                let descriptor = HKStatisticsCollectionQueryDescriptor(
                    predicate: .quantitySample(type: type, predicate: predicate),
                    options: isCumulative ? .cumulativeSum : .discreteAverage,
                    anchorDate: start,
                    intervalComponents: DateComponents(day: 1)
                )
                let collection = try await descriptor.result(for: store)
                var daysWithData = 0
                var total = 0.0
                collection.enumerateStatistics(from: start, to: end) { stats, _ in
                    if let q = isCumulative ? stats.sumQuantity() : stats.averageQuantity() {
                        daysWithData += 1
                        total += q.doubleValue(for: unit)
                    }
                }
                let avg = daysWithData > 0 ? total / Double(daysWithData) : 0
                s.lines.append(.init(label: label, value: "\(daysWithData)/30 jours avec données · moyenne \(fmtNumber(avg, 1)) \(unit.unitString)"))
            } catch {
                s.verdict = .warn
                s.lines.append(.init(label: label, value: "ERREUR : \(error.localizedDescription)"))
            }
        }

        // Poids : moyenne quotidienne (type discret) — exactement ce qu'il faut pour la courbe.
        do {
            let weightStart = Calendar.current.date(byAdding: .day, value: -90, to: end)!
            let descriptor = HKStatisticsCollectionQueryDescriptor(
                predicate: .quantitySample(type: HKQuantityType(.bodyMass), predicate: HKQuery.predicateForSamples(withStart: weightStart, end: end, options: [])),
                options: .discreteAverage,
                anchorDate: weightStart,
                intervalComponents: DateComponents(day: 1)
            )
            let collection = try await descriptor.result(for: store)
            var points = 0
            collection.enumerateStatistics(from: weightStart, to: end) { stats, _ in
                if stats.averageQuantity() != nil { points += 1 }
            }
            s.lines.append(.init(label: "Poids — points de courbe sur 90 j", value: "\(points)"))
            if points > 0 {
                s.findings.append("`HKStatisticsCollectionQuery` donne directement la série quotidienne pour la courbe de poids (\(points) points sur 90 jours) : pas besoin d'agréger à la main côté SwiftData pour les types quantitatifs.")
            }
        } catch {
            s.lines.append(.init(label: "Poids — série quotidienne", value: "ERREUR : \(error.localizedDescription)"))
        }

        s.findings.append("Les trous sont la norme : un jour sans donnée n'a pas de statistique du tout (pas un zéro). Les graphiques doivent interrompre la courbe, et la moyenne 7 j doit se calculer sur les jours présents, pas sur 7.")
        s.findings.append("Le sommeil, lui, est un type CATÉGORIE : `HKStatisticsCollectionQuery` ne s'y applique pas. L'agrégat par nuit est donc à calculer nous-mêmes — c'est le vrai travail de la couche d'import.")
        s.elapsedMs = Int(Date().timeIntervalSince(clock) * 1000)
        return s
    }

    // MARK: - 6. Sync incrémentale + arrière-plan

    func probeSyncAndBackground() async -> ReportSection {
        let clock = Date()
        var s = ReportSection(title: "6. Sync incrémentale et arrière-plan", verdict: .ok)

        // 6a. Requête ancrée : le mécanisme d'import incrémental.
        do {
            let descriptor = HKAnchoredObjectQueryDescriptor(
                predicates: [.categorySample(type: sleepType, predicate: nil)],
                anchor: nil,
                limit: nil
            )
            let first = try await descriptor.result(for: store)
            s.lines.append(.init(label: "Requête ancrée — 1er passage", value: "\(first.addedSamples.count) ajouts · \(first.deletedObjects.count) suppressions"))

            let second = try await HKAnchoredObjectQueryDescriptor(
                predicates: [.categorySample(type: sleepType, predicate: nil)],
                anchor: first.newAnchor,
                limit: nil
            ).result(for: store)
            s.lines.append(.init(label: "Requête ancrée — 2e passage (même ancre)", value: "\(second.addedSamples.count) ajouts · \(second.deletedObjects.count) suppressions"))

            if second.addedSamples.isEmpty {
                s.findings.append("L'import incrémental fonctionne : avec une ancre persistée, le 2e passage ne renvoie rien. C'est la brique d'import à construire (ancre en base, un passage par type).")
            }
            if first.deletedObjects.count > 0 {
                s.findings.append("\(first.deletedObjects.count) objet(s) supprimé(s) remontent dans l'historique : l'utilisateur PEUT effacer une donnée dans Santé. Les miroirs SwiftData doivent conserver l'`UUID` HealthKit et traiter les suppressions, sinon l'app affichera des nuits fantômes.")
            } else {
                s.findings.append("Conserver malgré tout l'`UUID` HealthKit dans SwiftData : les suppressions côté Santé ne remontent que par requête ancrée, et une donnée effacée doit disparaître de l'app.")
            }
        } catch {
            s.verdict = .warn
            s.lines.append(.init(label: "Requête ancrée", value: "ERREUR : \(error.localizedDescription)"))
        }

        // 6b. Observer query : la notification de changement.
        let observerFired: String = await withCheckedContinuation { continuation in
            var resumed = false
            let lock = NSLock()
            let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { _, completionHandler, error in
                completionHandler()
                lock.lock(); defer { lock.unlock() }
                if !resumed {
                    resumed = true
                    continuation.resume(returning: error == nil ? "déclenché" : "erreur : \(error!.localizedDescription)")
                }
            }
            store.execute(query)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                lock.lock(); defer { lock.unlock() }
                if !resumed {
                    resumed = true
                    continuation.resume(returning: "enregistré (pas de changement en 3 s — normal)")
                }
            }
        }
        s.lines.append(.init(label: "HKObserverQuery sommeil", value: observerFired))

        // 6c. Background delivery : vérifie surtout l'entitlement.
        let backgroundResult: String = await withCheckedContinuation { continuation in
            store.enableBackgroundDelivery(for: sleepType, frequency: .hourly) { success, error in
                if let error {
                    continuation.resume(returning: "REFUSÉ : \(error.localizedDescription)")
                } else {
                    continuation.resume(returning: success ? "activé (fréquence horaire)" : "retour false sans erreur")
                }
            }
        }
        s.lines.append(.init(label: "enableBackgroundDelivery(sommeil)", value: backgroundResult))
        if backgroundResult.hasPrefix("REFUSÉ") {
            s.verdict = .fail
            s.findings.append("La livraison en arrière-plan est refusée : l'entitlement `com.apple.developer.healthkit.background-delivery` manque ou n'est pas provisionné. Sans elle, l'app ne se met à jour qu'à l'ouverture — acceptable pour la démo, à corriger avant la sortie.")
        } else {
            s.findings.append("La livraison en arrière-plan est accordée (entitlement `background-delivery` OK). Pour le sommeil, la fréquence demandée est horaire ; HealthKit reste maître du moment réel de livraison. La fraîcheur doit être mesurée sur l'iPhone du fondateur, pas promise comme instantanée.")
        }
        let bgWeight: String = await withCheckedContinuation { continuation in
            store.enableBackgroundDelivery(for: HKQuantityType(.bodyMass), frequency: .immediate) { success, error in
                continuation.resume(returning: error.map { "REFUSÉ : \($0.localizedDescription)" } ?? (success ? "activé (immédiat)" : "false"))
            }
        }
        s.lines.append(.init(label: "enableBackgroundDelivery(poids, immédiat)", value: bgWeight))

        s.findings.append("Conséquence produit : « connecté à Apple Health en automatique » est tenable, mais la fraîcheur n'est pas instantanée. Afficher l'heure de dernière synchro plutôt que de laisser croire au temps réel.")
        s.elapsedMs = Int(Date().timeIntervalSince(clock) * 1000)
        return s
    }

    // MARK: - 7. Performance et robustesse

    func probePerformance() async -> ReportSection {
        let clock = Date()
        var s = ReportSection(title: "7. Performance et cas limites", verdict: .ok)

        // Coût d'une lecture large (ce que fera l'écran Aujourd'hui au lancement).
        let t0 = Date()
        let sleep30 = (try? await fetchSleep(days: 30))?.count ?? -1
        let sleepMs = Int(Date().timeIntervalSince(t0) * 1000)
        s.lines.append(.init(label: "Lecture sommeil 30 j", value: "\(sleep30) éch. en \(sleepMs) ms"))

        let t1 = Date()
        let sleep365 = (try? await fetchSleep(days: 365))?.count ?? -1
        let sleep365Ms = Int(Date().timeIntervalSince(t1) * 1000)
        s.lines.append(.init(label: "Lecture sommeil 365 j", value: "\(sleep365) éch. en \(sleep365Ms) ms"))

        // Fenêtre sans données : vérifie qu'on obtient un tableau vide, pas une erreur.
        do {
            let future = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
            let farFuture = Calendar.current.date(byAdding: .day, value: 60, to: Date())!
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.categorySample(type: sleepType, predicate: HKQuery.predicateForSamples(withStart: future, end: farFuture, options: []))],
                sortDescriptors: []
            )
            let empty = try await descriptor.result(for: store)
            s.lines.append(.init(label: "Fenêtre future (sans données)", value: "\(empty.count) éch. — pas d'erreur"))
        } catch {
            s.lines.append(.init(label: "Fenêtre future (sans données)", value: "ERREUR : \(error.localizedDescription)"))
        }

        s.lines.append(.init(label: "Types interrogés", value: "uniquement la liste close déclarée à l'autorisation"))
        s.findings.append("Le spike n'interroge jamais un type hors de la liste close : tester une éventuelle lecture non autorisée en demandant, par exemple, le tour de taille contredirait le principe de minimisation. Pour un type autorisé, HealthKit peut renvoyer un tableau vide aussi bien en cas d'absence de données que de refus de lecture ; l'interface doit gérer les deux cas sans les confondre.")

        if sleep365Ms > 1000 {
            s.verdict = .warn
            s.findings.append("Une lecture d'un an de sommeil prend \(sleep365Ms) ms : trop lent pour le chemin de lancement. L'écran Aujourd'hui doit lire SwiftData (déjà importé) et déclencher l'import HealthKit en tâche de fond.")
        } else {
            s.findings.append("Les lectures restent rapides (\(sleepMs) ms sur 30 j, \(sleep365Ms) ms sur 365 j), mais garder le principe : l'UI lit SwiftData, l'import HealthKit tourne à côté.")
        }
        s.findings.append("Une absence de données ne produit jamais d'erreur, juste un tableau vide — donc « pas de données » et « accès refusé » sont indiscernables côté API. L'onboarding doit vérifier explicitement, après la demande, qu'au moins une donnée arrive, et sinon guider vers Réglages > Santé.")
        s.elapsedMs = Int(Date().timeIntervalSince(clock) * 1000)
        return s
    }

    // MARK: - Lancement complet

    func runAll(progress: @escaping (String) -> Void) async -> SpikeReport {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var report = SpikeReport(
            deviceModel: hardwareModel(),
            osVersion: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        )
        progress("Autorisation…")
        report.sections.append(await probeAuthorization())
        progress("Sommeil…")
        report.sections.append(await probeSleep())
        progress("Séances…")
        report.sections.append(await probeWorkouts())
        progress("Poids et mesures…")
        report.sections.append(await probeBody())
        progress("Agrégats…")
        report.sections.append(await probeStatistics())
        progress("Sync et arrière-plan…")
        report.sections.append(await probeSyncAndBackground())
        progress("Performance…")
        report.sections.append(await probePerformance())
        progress("Terminé")
        return report
    }
}
