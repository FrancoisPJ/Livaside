import Foundation

/// Modèle de rapport du spike : des sections, chacune avec un verdict et des lignes.
/// Sérialisable en JSON (pour analyse) et en Markdown (pour lecture directe).

enum Verdict: String, Codable {
    case ok         // ça marche comme espéré
    case warn       // ça marche mais avec un piège à gérer
    case fail       // ça ne marche pas
    case info       // observation, pas de jugement

    var emoji: String {
        switch self {
        case .ok: return "✅"
        case .warn: return "⚠️"
        case .fail: return "❌"
        case .info: return "ℹ️"
        }
    }
}

struct ReportLine: Codable {
    var label: String
    var value: String
}

struct ReportSection: Codable, Identifiable {
    var id: String { title }
    var title: String
    var verdict: Verdict
    var elapsedMs: Int = 0
    var lines: [ReportLine] = []
    /// Conclusions à retenir pour le modèle de données / la promesse produit.
    var findings: [String] = []
}

struct SpikeReport: Codable {
    var generatedAt: Date = Date()
    var deviceModel: String
    var osVersion: String
    var sections: [ReportSection] = []

    var markdown: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZ"
        var out = "# Spike HealthKit Livaside — rapport d'exécution\n\n"
        out += "- Généré : \(df.string(from: generatedAt))\n"
        out += "- Appareil : \(deviceModel) — iOS \(osVersion)\n\n"

        out += "## Résumé\n\n"
        for s in sections {
            out += "- \(s.verdict.emoji) **\(s.title)** (\(s.elapsedMs) ms)\n"
        }
        out += "\n"

        for s in sections {
            out += "## \(s.verdict.emoji) \(s.title)\n\n"
            if !s.lines.isEmpty {
                out += "| Mesure | Valeur |\n| --- | --- |\n"
                for l in s.lines {
                    out += "| \(l.label) | \(l.value) |\n"
                }
                out += "\n"
            }
            if !s.findings.isEmpty {
                out += "**À retenir**\n\n"
                for f in s.findings { out += "- \(f)\n" }
                out += "\n"
            }
        }
        return out
    }
}

// MARK: - Formatage

func fmtDuration(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite else { return "—" }
    let total = Int(seconds.rounded())
    let h = total / 3600
    let m = (total % 3600) / 60
    if h > 0 { return "\(h) h \(String(format: "%02d", m))" }
    return "\(m) min"
}

func fmtDate(_ date: Date?) -> String {
    guard let date else { return "—" }
    let df = DateFormatter()
    df.dateFormat = "dd/MM/yyyy HH:mm"
    return df.string(from: date)
}

func fmtDay(_ date: Date?) -> String {
    guard let date else { return "—" }
    let df = DateFormatter()
    df.dateFormat = "dd/MM"
    return df.string(from: date)
}

func fmtNumber(_ value: Double, _ digits: Int = 1) -> String {
    String(format: "%.\(digits)f", value)
}

// MARK: - Union d'intervalles

struct Interval {
    var start: Date
    var end: Date
    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

/// Fusionne les intervalles qui se chevauchent. C'est l'outil central du spike :
/// sans ça, additionner des échantillons de sommeil venant de plusieurs sources
/// compte deux fois les mêmes minutes.
func mergeIntervals(_ intervals: [Interval]) -> [Interval] {
    guard !intervals.isEmpty else { return [] }
    let sorted = intervals.sorted { $0.start < $1.start }
    var merged: [Interval] = [sorted[0]]
    for current in sorted.dropFirst() {
        var last = merged.removeLast()
        if current.start <= last.end {
            last.end = max(last.end, current.end)
            merged.append(last)
        } else {
            merged.append(last)
            merged.append(current)
        }
    }
    return merged
}

func totalDuration(_ intervals: [Interval]) -> TimeInterval {
    intervals.reduce(0) { $0 + $1.duration }
}

/// Nombre de paires d'intervalles qui se chevauchent (indicateur de doublons).
func overlappingPairCount(_ intervals: [Interval]) -> Int {
    let sorted = intervals.sorted { $0.start < $1.start }
    var count = 0
    for i in sorted.indices {
        for j in sorted.index(after: i)..<sorted.endIndex {
            if sorted[j].start < sorted[i].end {
                count += 1
            } else {
                break
            }
        }
    }
    return count
}
