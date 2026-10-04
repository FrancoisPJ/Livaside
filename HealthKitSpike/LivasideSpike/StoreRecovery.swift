import Foundation
import SQLite3
import SwiftData

/// Ce qui s'est mal passé à l'ouverture du stockage local, pour prévenir l'utilisateur (QUAL-01).
enum StoreOpeningIssue: Equatable {
    /// Le stockage était illisible (migration ratée d'une ancienne version) : il est mis de côté dans
    /// `backup` et l'app repart d'un stockage neuf, où `recoveredMeals` repas ont été réimportés.
    case recovered(recoveredMeals: Int, backup: URL)
    /// Aucun stockage sur disque n'a pu être ouvert : l'app tourne en mémoire. Les repas relus sont
    /// affichés, mais rien de ce qui est saisi ne survivra à la fermeture de l'app.
    case inMemoryOnly(recoveredMeals: Int)
}

struct OpenedStore {
    let container: ModelContainer
    let issue: StoreOpeningIssue?
}

extension LivasideStore {
    /// Ouvre le stockage décrit par `configuration` sans jamais planter au lancement.
    ///
    /// 1. Ouverture normale.
    /// 2. Si elle échoue, les fichiers du stockage sont déplacés ensemble (`-wal` compris, sinon les
    ///    derniers repas saisis seraient perdus) dans un dossier daté, puis un stockage neuf est créé
    ///    et les repas y sont réimportés depuis la copie. Santé se réimporte tout seul.
    /// 3. Si le déplacement ou le stockage neuf échouent, repli en mémoire avec les repas relus.
    ///
    /// La copie mise de côté n'est jamais supprimée.
    static func open(_ configuration: ModelConfiguration, now: Date = .now) -> OpenedStore {
        if let container = try? ModelContainer(for: schema, configurations: configuration) {
            return OpenedStore(container: container, issue: nil)
        }
        let storeURL = configuration.url
        let backup = setAside(storeURL, now: now)
        let mealsSource = backup?.appendingPathComponent(storeURL.lastPathComponent) ?? storeURL
        let meals = (try? LegacyStoreReader.meals(at: mealsSource)) ?? []

        if backup != nil, let container = try? ModelContainer(for: schema, configurations: configuration) {
            let count = (try? insert(meals, into: container)) ?? 0
            return OpenedStore(container: container, issue: .recovered(recoveredMeals: count, backup: backup!))
        }
        do {
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
            let count = (try? insert(meals, into: container)) ?? 0
            return OpenedStore(container: container, issue: .inMemoryOnly(recoveredMeals: count))
        } catch {
            // Un conteneur en mémoire ne dépend ni du disque ni d'un ancien stockage : s'il échoue,
            // c'est le schéma lui-même qui est faux, une erreur de programmation à voir dès le premier test.
            fatalError("Schéma Livaside invalide : \(error.localizedDescription)")
        }
    }

    /// Déplace `store`, `store-wal` et `store-shm` dans `Livaside-illisible-<horodatage>/` à côté,
    /// en gardant leurs noms : SQLite ne retrouve le journal `-wal` que sous ce nom. Tout ou rien :
    /// un `-wal` resté en place pourrait être rejoué sur le stockage neuf. Renvoie nil en cas d'échec.
    private static func setAside(_ storeURL: URL, now: Date) -> URL? {
        let fileManager = FileManager.default
        let folder = storeURL.deletingLastPathComponent()
            .appendingPathComponent("Livaside-illisible-\(Int(now.timeIntervalSince1970))", isDirectory: true)
        let files = ["-wal", "-shm", ""].map { URL(fileURLWithPath: storeURL.path + $0) }
            .filter { fileManager.fileExists(atPath: $0.path) }
        var moved: [(from: URL, to: URL)] = []
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            for file in files {
                let destination = folder.appendingPathComponent(file.lastPathComponent)
                try fileManager.moveItem(at: file, to: destination)
                moved.append((file, destination))
            }
            return folder
        } catch {
            for move in moved.reversed() { try? fileManager.moveItem(at: move.to, to: move.from) }
            return nil
        }
    }

    /// Insère les repas relus, sauf ceux déjà présents (même identifiant) : rejouable sans doublon.
    @discardableResult
    static func insert(_ meals: [LegacyStoreReader.MealRow], into container: ModelContainer) throws -> Int {
        guard !meals.isEmpty else { return 0 }
        let context = ModelContext(container)
        let existing = Set(try context.fetch(FetchDescriptor<Meal>()).map(\.id))
        var count = 0
        for row in meals where !existing.contains(row.id) {
            let meal = Meal(id: row.id, date: row.date, name: row.name, calories: row.calories,
                            proteinGrams: row.proteinGrams, carbsGrams: row.carbsGrams, fatGrams: row.fatGrams)
            meal.createdAt = row.createdAt ?? row.date
            meal.updatedAt = row.updatedAt ?? row.date
            context.insert(meal)
            count += 1
        }
        try context.save()
        return count
    }
}

/// Relit les repas d'un stockage SwiftData que le schéma actuel refuse d'ouvrir, directement en SQLite.
/// Indépendant du schéma : seules les colonnes présentes sont lues, une colonne absente prend sa valeur
/// par défaut. La lecture se fait sur une copie temporaire : SQLite doit pouvoir écrire pour rejouer
/// le journal `-wal` (où dorment les derniers repas), et le stockage d'origine reste intact.
enum LegacyStoreReader {
    struct MealRow: Equatable {
        var id: UUID
        var date: Date
        var name: String
        var calories: Int
        var proteinGrams: Double
        var carbsGrams: Double
        var fatGrams: Double
        var createdAt: Date?
        var updatedAt: Date?
    }

    struct ReadError: Error { let message: String }

    static func meals(at url: URL) throws -> [MealRow] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let copyFolder = fileManager.temporaryDirectory.appendingPathComponent("LivasideRecovery-\(UUID())")
        try fileManager.createDirectory(at: copyFolder, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: copyFolder) }
        let copy = copyFolder.appendingPathComponent(url.lastPathComponent)
        for suffix in ["", "-wal"] where fileManager.fileExists(atPath: url.path + suffix) {
            try fileManager.copyItem(atPath: url.path + suffix, toPath: copy.path + suffix)
        }

        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        guard sqlite3_open_v2(copy.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            throw ReadError(message: db.map { String(cString: sqlite3_errmsg($0)) } ?? "ouverture impossible")
        }
        // Convention Core Data : table `Z` + entité en majuscules, colonnes `Z` + propriété en majuscules.
        let columns = try names(of: "ZMEAL", in: db)
        guard columns.contains("ZNAME"), columns.contains("ZDATE") else { return [] }
        let wanted = ["ZID", "ZDATE", "ZNAME", "ZCALORIES", "ZPROTEINGRAMS", "ZCARBSGRAMS", "ZFATGRAMS",
                      "ZCREATEDAT", "ZUPDATEDAT"]
        let selected = wanted.map { columns.contains($0) ? $0 : "NULL" }
        let statement = try prepare("SELECT \(selected.joined(separator: ", ")) FROM ZMEAL", in: db)
        defer { sqlite3_finalize(statement) }

        var rows: [MealRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let date = date(statement, 1), let name = text(statement, 2) else { continue }
            rows.append(MealRow(id: uuid(statement, 0) ?? UUID(), date: date, name: name,
                                calories: Int(sqlite3_column_double(statement, 3).rounded()),
                                proteinGrams: sqlite3_column_double(statement, 4),
                                carbsGrams: sqlite3_column_double(statement, 5),
                                fatGrams: sqlite3_column_double(statement, 6),
                                createdAt: self.date(statement, 7), updatedAt: self.date(statement, 8)))
        }
        return rows
    }

    private static func names(of table: String, in db: OpaquePointer?) throws -> Set<String> {
        let statement = try prepare("PRAGMA table_info(\(table))", in: db)
        defer { sqlite3_finalize(statement) }
        var names: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = text(statement, 1) { names.insert(name.uppercased()) }
        }
        return names
    }

    private static func prepare(_ sql: String, in db: OpaquePointer?) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ReadError(message: String(cString: sqlite3_errmsg(db)))
        }
        return statement
    }

    private static func text(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    /// Core Data range les dates en secondes depuis le 1er janvier 2001.
    private static func date(_ statement: OpaquePointer?, _ index: Int32) -> Date? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return Date(timeIntervalSinceReferenceDate: sqlite3_column_double(statement, index))
    }

    /// Un UUID est rangé en BLOB de 16 octets ; la forme texte est acceptée par prudence.
    private static func uuid(_ statement: OpaquePointer?, _ index: Int32) -> UUID? {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_BLOB where sqlite3_column_bytes(statement, index) == 16:
            guard let bytes = sqlite3_column_blob(statement, index) else { return nil }
            var raw = uuid_t(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
            withUnsafeMutableBytes(of: &raw) { $0.copyMemory(from: UnsafeRawBufferPointer(start: bytes, count: 16)) }
            return UUID(uuid: raw)
        case SQLITE_TEXT:
            return text(statement, index).flatMap(UUID.init(uuidString:))
        default:
            return nil
        }
    }
}
