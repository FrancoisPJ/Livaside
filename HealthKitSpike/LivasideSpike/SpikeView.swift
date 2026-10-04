import SwiftUI

@MainActor
final class SpikeViewModel: ObservableObject {
    @Published var status: String = "Prêt"
    @Published var running = false
    @Published var report: SpikeReport?
    @Published var savedPaths: [String] = []

    private let probe = HealthKitProbe()

    func run() async {
        guard !running else { return }
        running = true
        status = "Démarrage…"
        let result = await probe.runAll { [weak self] step in
            Task { @MainActor in self?.status = step }
        }
        report = result
        savedPaths = save(result)
        running = false
        status = "Terminé — \(result.sections.count) sections"
    }

    /// Écrit le rapport dans Documents : récupérable via Xcode, Fichiers, ou
    /// `xcrun devicectl device copy from --domain-type appDataContainer`.
    private func save(_ report: SpikeReport) -> [String] {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var written: [String] = []
        let md = dir.appendingPathComponent("spike-healthkit.md")
        if let data = report.markdown.data(using: .utf8) {
            try? data.write(to: md)
            written.append(md.lastPathComponent)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(report) {
            let json = dir.appendingPathComponent("spike-healthkit.json")
            try? data.write(to: json)
            written.append(json.lastPathComponent)
        }
        return written
    }
}

struct SpikeView: View {
    @StateObject private var model = SpikeViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if model.running {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(model.status)
                        }
                    } else {
                        Button {
                            Task { await model.run() }
                        } label: {
                            Label(model.report == nil ? "Lancer le diagnostic" : "Relancer", systemImage: "stethoscope")
                        }
                        Text(model.status).foregroundStyle(.secondary).font(.footnote)
                    }
                } header: {
                    Text("Spike HealthKit")
                } footer: {
                    Text("Lit Santé en lecture seule. Rien n'est envoyé : le rapport reste sur l'iPhone.")
                }

                if let report = model.report {
                    Section("Résumé") {
                        ForEach(report.sections) { section in
                            NavigationLink {
                                SectionDetailView(section: section)
                            } label: {
                                HStack {
                                    Text(section.verdict.emoji)
                                    VStack(alignment: .leading) {
                                        Text(section.title).font(.subheadline)
                                        Text("\(section.lines.count) mesures · \(section.elapsedMs) ms")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    Section("Rapport") {
                        if !model.savedPaths.isEmpty {
                            Text("Enregistré : \(model.savedPaths.joined(separator: ", "))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ShareLink(item: report.markdown) {
                            Label("Partager le rapport", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle("Livaside · Spike")
        }
        .task {
            // Lancement automatique : la feuille d'autorisation Santé apparaît
            // tout de suite, le reste s'enchaîne sans intervention.
            await model.run()
        }
    }
}

struct SectionDetailView: View {
    let section: ReportSection

    var body: some View {
        List {
            if !section.findings.isEmpty {
                Section("À retenir") {
                    ForEach(Array(section.findings.enumerated()), id: \.offset) { _, finding in
                        Text(finding).font(.callout)
                    }
                }
            }
            Section("Mesures") {
                ForEach(Array(section.lines.enumerated()), id: \.offset) { _, line in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.label).font(.caption).foregroundStyle(.secondary)
                        Text(line.value).font(.callout).textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle(section.verdict.emoji + " " + section.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
