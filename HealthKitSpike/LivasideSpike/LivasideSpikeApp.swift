import SwiftUI
import SwiftData

@main
struct LivasideSpikeApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var health: HealthKitSync

    init() {
        Theme.applyNavigationBarFonts()
        let container = LivasideStore.openLocalContainer()
        let health = HealthKitSync(container: container)
        modelContainer = container
        _health = StateObject(wrappedValue: health)
        // Les observateurs doivent exister dès le lancement pour que HealthKit puisse réveiller
        // l'app en arrière-plan quand de nouvelles données arrivent.
        Task { await health.startObservingIfAlreadyAuthorized() }
    }

    var body: some Scene {
        WindowGroup {
            StoreSwitcher(realContainer: modelContainer)
                .environmentObject(health)
        }
    }
}

/// Choisit entre les vraies données et la démo. La démo vit dans un stockage séparé, en mémoire.
private struct StoreSwitcher: View {
    let realContainer: ModelContainer
    @AppStorage("demoMode") private var demoMode = false
    @State private var demoContainer: ModelContainer?

    var body: some View {
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
