import SwiftData
import XCTest
@testable import QACore

/// QUAL-01 : un stockage d'une version précédente que le schéma actuel refuse d'ouvrir.
/// `calories` y était un texte : Core Data ne sait pas migrer ce changement de type tout seul.
enum PreviousVersion {
    @Model
    final class Meal {
        var id: UUID
        var date: Date
        var name: String
        var calories: String
        var proteinGrams: Double
        var createdAt: Date

        init(id: UUID, date: Date, name: String, calories: String, proteinGrams: Double) {
            self.id = id
            self.date = date
            self.name = name
            self.calories = calories
            self.proteinGrams = proteinGrams
            self.createdAt = date
        }
    }
}

final class StoreRecoveryTests: XCTestCase {
    private var folder: URL!
    private var storeURL: URL { folder.appendingPathComponent("default.store") }
    private var configuration: ModelConfiguration {
        ModelConfiguration(schema: LivasideStore.schema, url: storeURL, cloudKitDatabase: .none)
    }

    private let breakfast = PreviousVersion.Meal(id: UUID(), date: Date(timeIntervalSince1970: 1_790_000_000),
                                                 name: "Skyr et granola", calories: "420", proteinGrams: 28)
    private let dinner = PreviousVersion.Meal(id: UUID(), date: Date(timeIntervalSince1970: 1_790_040_000),
                                              name: "Soupe", calories: "310", proteinGrams: 0)

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("StoreRecovery-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)
        try? FileManager.default.removeItem(at: folder)
    }

    private func writePreviousVersionStore() throws {
        let schema = Schema([PreviousVersion.Meal.self])
        let container = try ModelContainer(for: schema,
                                           configurations: ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none))
        let context = ModelContext(container)
        context.insert(breakfast)
        context.insert(dinner)
        try context.save()
    }

    private func meals(in container: ModelContainer) throws -> [Meal] {
        try ModelContext(container).fetch(FetchDescriptor<Meal>(sortBy: [SortDescriptor(\.date)]))
    }

    func testReadableStoreOpensWithoutIssue() throws {
        XCTAssertNil(LivasideStore.open(configuration).issue)
        XCTAssertNil(LivasideStore.open(configuration).issue, "réouverture d'un stockage au schéma actuel")
    }

    func testUnreadableStoreIsSetAsideAndMealsReimported() throws {
        try writePreviousVersionStore()
        XCTAssertThrowsError(try ModelContainer(for: LivasideStore.schema, configurations: configuration),
                             "le scénario doit reproduire une migration ratée")

        let opened = LivasideStore.open(configuration, now: Date(timeIntervalSince1970: 1_800_000_000))

        let backup = folder.appendingPathComponent("Livaside-illisible-1800000000")
        XCTAssertEqual(opened.issue, .recovered(recoveredMeals: 2, backup: backup))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.appendingPathComponent("default.store").path),
                      "la copie mise de côté est conservée sous son nom d'origine")

        let recovered = try meals(in: opened.container)
        XCTAssertEqual(recovered.map(\.id), [breakfast.id, dinner.id], "mêmes identifiants : la reprise LIV-22 reste rejouable")
        XCTAssertEqual(recovered.map(\.name), ["Skyr et granola", "Soupe"])
        XCTAssertEqual(recovered.map(\.date), [breakfast.date, dinner.date])
        XCTAssertEqual(recovered.map(\.calories), [420, 310])
        XCTAssertEqual(recovered.map(\.proteinGrams), [28, 0])
        XCTAssertEqual(recovered.map(\.carbsGrams), [0, 0], "colonne absente de l'ancienne version")
        XCTAssertEqual(recovered.first?.createdAt, breakfast.date)
    }

    func testRecoveredStoreReopensNormally() throws {
        try writePreviousVersionStore()
        _ = LivasideStore.open(configuration)

        let reopened = LivasideStore.open(configuration)
        XCTAssertNil(reopened.issue)
        XCTAssertEqual(try meals(in: reopened.container).count, 2, "ni perte ni doublon au lancement suivant")
    }

    func testFallsBackToMemoryWhenStoreCannotBeSetAside() throws {
        try writePreviousVersionStore()
        // Dossier en lecture seule : ni déplacement ni stockage neuf possibles (avant : fatalError).
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)

        let opened = LivasideStore.open(configuration)

        XCTAssertEqual(opened.issue, .inMemoryOnly(recoveredMeals: 2))
        XCTAssertEqual(try meals(in: opened.container).map(\.name), ["Skyr et granola", "Soupe"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path), "l'ancien stockage n'est pas touché")
    }

    func testMissingMealTableReadsNothing() throws {
        let schema = Schema([SyncState.self])
        _ = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none))
        XCTAssertEqual(try LegacyStoreReader.meals(at: storeURL), [])
    }
}
