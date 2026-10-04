import SwiftUI
import SwiftData

@main
struct LivasideSpikeApp: App {
    private let modelContainer: ModelContainer
    private let storeIssue: StoreOpeningIssue?
    @StateObject private var health: HealthKitSync

    init() {
        Theme.applyNavigationBarFonts()
        let opened = LivasideStore.openLocalContainer()
        let container = opened.container
        storeIssue = opened.issue
        let health = HealthKitSync(container: container)
        modelContainer = container
        _health = StateObject(wrappedValue: health)
        // Les observateurs doivent exister dès le lancement pour que HealthKit puisse réveiller
        // l'app en arrière-plan quand de nouvelles données arrivent.
        Task { await health.startObservingIfAlreadyAuthorized() }
    }

    var body: some Scene {
        WindowGroup {
            StoreSwitcher(realContainer: modelContainer, storeIssue: storeIssue)
                .environmentObject(health)
        }
    }
}

/// Choisit entre les vraies données et la démo. La démo vit dans un stockage séparé, en mémoire.
private struct StoreSwitcher: View {
    let realContainer: ModelContainer
    let storeIssue: StoreOpeningIssue?
    @AppStorage("demoMode") private var demoMode = false
    @State private var demoContainer: ModelContainer?
    @State private var showsStoreIssue = true

    var body: some View {
        content
            .alert(storeIssue?.title ?? "", isPresented: Binding(get: { storeIssue != nil && showsStoreIssue },
                                                                 set: { showsStoreIssue = $0 })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(storeIssue?.message ?? "")
            }
    }

    @ViewBuilder private var content: some View {
        if demoMode {
            if let demoContainer {
                LivasideRootView().modelContainer(demoContainer)
            } else {
                ProgressView("Préparation de la démo…")
                    .task { demoContainer = try? DemoData.makeContainer() }
            }
        } else {
            LivasideRootView().modelContainer(realContainer)
                .onAppear { demoContainer = nil }
        }
    }
}

private extension StoreOpeningIssue {
    var title: String {
        switch self {
        case .recovered: "Stockage réparé"
        case .inMemoryOnly: "Enregistrement impossible"
        }
    }

    var message: String {
        switch self {
        case let .recovered(meals, _):
            let mealsText = meals == 0 ? "Aucun repas n’a pu être relu" : "\(meals) repas ont été récupérés"
            return "Les données de Livaside n’ont pas pu être ouvertes après la mise à jour. \(mealsText) ; "
                + "vos données Apple Health vont se réimporter. Une copie de l’ancien stockage reste sur l’iPhone."
        case let .inMemoryOnly(meals):
            let shown = meals == 0 ? "" : "Vos \(meals) repas sont affichés, mais "
            return shown + "ce que vous saisissez ne sera pas conservé après la fermeture de l’app. "
                + "Libérez de l’espace ou redémarrez l’iPhone, puis rouvrez Livaside."
        }
    }
}
