import XCTest
@testable import QACore

final class LivasideDateTests: XCTestCase {
    private let originalTZ = ProcessInfo.processInfo.environment["TZ"]

    private func setSystemTimeZone(_ id: String) {
        setenv("TZ", id, 1)
        tzset()
        NSTimeZone.resetSystemTimeZone()
    }

    override func tearDown() {
        if let originalTZ { setenv("TZ", originalTZ, 1) } else { unsetenv("TZ") }
        tzset()
        NSTimeZone.resetSystemTimeZone()
    }

    /// Un instant doit toujours tomber dans le jour du calendrier courant, même si l'utilisateur
    /// a changé de fuseau depuis le lancement de l'app (voyage).
    func testKeyFollowsTimeZoneChangeAfterFirstUse() {
        setSystemTimeZone("Europe/Paris")
        _ = LivasideDate.key(for: Date())   // initialise le formateur statique

        setSystemTimeZone("Pacific/Auckland")
        // 2026-03-10 12:30 UTC = 2026-03-11 01:30 à Auckland (UTC+13), mais le 10 à Paris.
        let instant = Date(timeIntervalSince1970: 1_773_145_800)
        XCTAssertEqual(LivasideDate.key(for: instant), "2026-03-11")
    }

    func testKeyOfStartOfDayIsThatDayAcrossDST() {
        setSystemTimeZone("Europe/Paris")
        let cal = LivasideDate.calendar
        // 2026-03-29 : passage à l'heure d'été (journée de 23 h) ; 2026-10-25 : retour (25 h).
        for key in ["2026-03-29", "2026-10-25"] {
            let parts = key.split(separator: "-").map { Int($0)! }
            let day = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))!
            XCTAssertEqual(LivasideDate.key(for: LivasideDate.startOfDay(day)), key)
            XCTAssertEqual(LivasideDate.key(for: day.addingTimeInterval(20 * 3_600)), key)
        }
    }
}
