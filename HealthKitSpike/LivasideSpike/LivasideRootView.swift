import Charts
import SwiftData
import SwiftUI

struct LivasideRootView: View {
    @State private var tab = Self.initialTab

    var body: some View {
        TabView(selection: $tab) {
            TodayView()
                .tabItem { Label("Aujourd’hui", systemImage: "sun.max.fill") }
                .tag("today")
            AddMealView()
                .tabItem { Label("Ajouter", systemImage: "plus.circle.fill") }
                .tag("meal")
            TrendsView()
                .tabItem { Label("Tendances", systemImage: "chart.xyaxis.line") }
                .tag("trends")
        }
        .tint(Theme.sauge)
    }

    private static var initialTab: String { Capture.tab ?? "today" }
}

/// Réglages des captures d'écran, lus dans les arguments de lancement (build Debug seulement) :
/// `-captureTab today|meal|trends` ouvre un onglet, `-captureMode YES` masque le bandeau de démo,
/// `-captureScroll end` cale la liste en bas, `-captureRange 30` choisit la période des tendances,
/// `-captureKeyboard NO` ouvre « Ajouter un repas » sans clavier.
private enum Capture {
    #if DEBUG
    static let tab = UserDefaults.standard.string(forKey: "captureTab")
    static let isActive = UserDefaults.standard.bool(forKey: "captureMode")
    static let scrollsToEnd = UserDefaults.standard.string(forKey: "captureScroll") == "end"
    static let range = UserDefaults.standard.integer(forKey: "captureRange")
    static let showsKeyboard = UserDefaults.standard.string(forKey: "captureKeyboard") != "NO"
    #else
    static let tab: String? = nil
    static let isActive = false
    static let scrollsToEnd = false
    static let range = 0
    static let showsKeyboard = true
    #endif
    static let endID = "capture-end"
}

private extension View {
    /// `-captureScroll end` : cale la liste sur sa dernière ligne (`Capture.endID`), au-dessus de la barre d'onglets.
    func scrollsToEndForCapture() -> some View {
        ScrollViewReader { proxy in
            task {
                guard Capture.scrollsToEnd else { return }
                // La liste doit être en place, sinon le défilement est ignoré.
                try? await Task.sleep(for: .milliseconds(500))
                proxy.scrollTo(Capture.endID, anchor: .bottom)
            }
        }
    }
}

private struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var health: HealthKitSync
    @AppStorage("demoMode") private var demoMode = false
    @Query(sort: \Meal.date, order: .reverse) private var meals: [Meal]
    @Query(sort: \DailyHealthSnapshot.day, order: .reverse) private var snapshots: [DailyHealthSnapshot]
    @Query private var syncStates: [SyncState]

    private var today: DailyHealthSnapshot? {
        snapshots.first { $0.dayKey == LivasideDate.key(for: .now) }
    }
    private var todayMeals: [Meal] {
        meals.filter { LivasideDate.calendar.isDateInToday($0.date) }
    }

    private var showsDemoBanner: Bool { demoMode && !Capture.isActive }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Votre suivi, sans la corvée.")
                                .font(.headline)
                            Text(lastSyncText)
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                        }
                        Spacer()
                        if !demoMode {
                            Button {
                                Task { await health.synchronize() }
                            } label: {
                                if health.isSyncing {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .disabled(health.isSyncing)
                            .accessibilityLabel("Synchroniser Apple Health")
                        }
                    }
                    .cardRow(showsDemoBanner || (!demoMode && health.problem != nil) ? .top : .single)
                    if showsDemoBanner {
                        Label("Mode démo : données fictives", systemImage: "theatermasks.fill")
                            .font(.caption).foregroundStyle(Theme.inkSoft)
                            .cardRow(.bottom)
                    } else if !demoMode, let problem = health.problem {
                        Text(problem).font(.caption).foregroundStyle(Theme.inkSoft)
                            .cardRow(.bottom)
                    }
                }

                Section {
                    MetricRow(icon: "bed.double.fill", color: Theme.sleep, title: "Cette nuit", value: hours(today?.sleepHours), detail: today?.sleepHours == nil ? "Aucune donnée de sommeil reçue" : "Durée de sommeil")
                        .cardRow()
                } header: { SectionTitle("Sommeil") }

                Section {
                    MetricRow(icon: "figure.run", color: Theme.sport, title: "Séances aujourd’hui", value: "\(today?.workoutCount ?? 0)", detail: workoutDetail)
                        .cardRow()
                } header: { SectionTitle("Activité") }

                Section {
                    MetricRow(icon: "scalemass.fill", color: Theme.weight, title: "Dernière mesure", value: kilograms(latestWeighIn?.weightKg), detail: weightDetail)
                        .cardRow()
                } header: { SectionTitle("Poids") }

                Section {
                    if todayMeals.isEmpty {
                        EmptyCard(title: "Aucun repas enregistré", systemImage: "fork.knife", description: "Ajoutez un repas en quelques secondes.")
                            .cardRow()
                    } else {
                        ForEach(todayMeals) { meal in
                            HStack {
                                Image(systemName: "fork.knife").foregroundStyle(Theme.nutrition).frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text(meal.name)
                                    Text(time(meal.date)).font(.caption).foregroundStyle(Theme.inkSoft)
                                }
                                Spacer()
                                Text("\(meal.calories) kcal").foregroundStyle(Theme.inkSoft)
                            }
                            .cardRow(meal.id == todayMeals.first?.id ? .top : .middle)
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.delete(todayMeals[index]) }
                            try? modelContext.save()
                        }
                        HStack {
                            Text("Total").font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(todayMeals.reduce(0) { $0 + $1.calories }) kcal")
                                .font(Theme.number(.title3))
                        }
                        .cardRow(.bottom)
                        .id(Capture.endID)
                    }
                } header: { SectionTitle("Repas") }
            }
            .themedList()
            .scrollsToEndForCapture()
            .navigationTitle("Aujourd’hui")
            .toolbar {
                Menu {
                    Toggle("Mode démo", systemImage: "theatermasks", isOn: $demoMode)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Options")
            }
            .task {
                if !demoMode { await health.synchronize() }
            }
            .refreshable {
                if !demoMode { await health.synchronize() }
            }
        }
    }

    private var latestWeighIn: DailyHealthSnapshot? {
        snapshots.first { $0.weightKg != nil }
    }
    private var weightDetail: String {
        guard let day = latestWeighIn?.day else { return "Aucune mesure reçue" }
        if LivasideDate.calendar.isDateInToday(day) { return "Ce matin" }
        return "Mesuré le \(day.formatted(.dateTime.day().month()))"
    }
    private var workoutDetail: String {
        guard let today, today.workoutCount > 0 else { return "Aucune séance reçue" }
        return "\(Int(today.workoutMinutes.rounded())) min actives"
    }
    private var lastSyncText: String {
        guard let date = syncStates.first?.lastSuccessfulSync else { return "Connexion Apple Health à terminer" }
        return "Dernière synchro : \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}

private struct AddMealView: View {
    private enum Field { case name, calories }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meal.date, order: .reverse) private var meals: [Meal]
    @FocusState private var focus: Field?
    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var date = Date()
    @State private var lastSaved: String?

    /// Les derniers repas différents : un repas habituel se ressaisit en deux touches.
    private var recentMeals: [Meal] {
        var seen = Set<String>()
        return meals.filter { seen.insert($0.name.lowercased()).inserted }.prefix(5).map { $0 }
    }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Int(calories) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ex. Yaourt et granola", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .focused($focus, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focus = .calories }
                        .cardRow(.top)
                    TextField("Calories", text: $calories)
                        .keyboardType(.numberPad)
                        .focused($focus, equals: .calories)
                        .cardRow(.middle)
                    DatePicker("Heure", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .cardRow(.bottom)
                } header: { SectionTitle("Le minimum pour l’enregistrer") }
                if !recentMeals.isEmpty {
                    Section {
                        ForEach(Array(recentMeals.enumerated()), id: \.element.id) { index, meal in
                            Button { reuse(meal) } label: {
                                HStack {
                                    Text(meal.name).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Text("\(meal.calories) kcal").foregroundStyle(Theme.inkSoft)
                                }
                            }
                            .cardRow(.at(index, of: recentMeals.count))
                        }
                    } header: { SectionTitle("Récents") }
                }
                Section {
                    macroField("Protéines", value: $protein).cardRow(.top)
                    macroField("Glucides", value: $carbs).cardRow(.middle)
                    macroField("Lipides", value: $fat).cardRow(.bottom)
                } header: { SectionTitle("Macros (facultatif)") }
                if let lastSaved {
                    Label("\(lastSaved) enregistré", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.sauge)
                        .cardRow()
                }
            }
            .themedList()
            .navigationTitle("Ajouter un repas")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                // L'onglet reste en mémoire : sans ça, un repas saisi à midi garderait l'heure du matin.
                date = .now
                lastSaved = nil
                if Capture.showsKeyboard { focus = .name }
            }
        }
    }

    @ViewBuilder private func macroField(_ label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: value).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
            Text("g").foregroundStyle(Theme.inkSoft)
        }
    }
    private func reuse(_ meal: Meal) {
        name = meal.name
        calories = "\(meal.calories)"
        protein = grams(meal.proteinGrams)
        carbs = grams(meal.carbsGrams)
        fat = grams(meal.fatGrams)
        date = .now
        focus = nil
    }
    private func grams(_ value: Double) -> String {
        value == 0 ? "" : value.formatted(.number.precision(.fractionLength(0...1)))
    }
    private func save() {
        guard let kcal = Int(calories) else { return }
        let mealName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(Meal(
            date: date, name: mealName, calories: kcal,
            proteinGrams: Double(protein.replacingOccurrences(of: ",", with: ".")) ?? 0,
            carbsGrams: Double(carbs.replacingOccurrences(of: ",", with: ".")) ?? 0,
            fatGrams: Double(fat.replacingOccurrences(of: ",", with: ".")) ?? 0
        ))
        try? modelContext.save()
        lastSaved = mealName
        name = ""; calories = ""; protein = ""; carbs = ""; fat = ""
        date = .now
        focus = nil
    }
}

private struct TrendsView: View {
    @Query(sort: \DailyHealthSnapshot.day) private var snapshots: [DailyHealthSnapshot]
    @State private var range = Capture.range == 30 ? 30 : 7

    private var data: [DailyHealthSnapshot] {
        let today = LivasideDate.startOfDay(.now)
        let firstDay = LivasideDate.calendar.date(byAdding: .day, value: -(range - 1), to: today)!
        return snapshots.filter { $0.day >= firstDay && $0.day <= today }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Période", selection: $range) {
                        Text("7 jours").tag(7)
                        Text("30 jours").tag(30)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                let sleep = data.compactMap { snapshot in snapshot.sleepHours.map { TrendPoint(day: snapshot.day, value: $0) } }
                trendSection(title: "Sommeil", systemImage: "bed.double.fill", color: Theme.sleep, unit: "h", values: sleep) {
                    sleepChart(sleep)
                }
                let weight = data.compactMap { snapshot in snapshot.weightKg.map { TrendPoint(day: snapshot.day, value: $0) } }
                trendSection(title: "Poids", systemImage: "scalemass.fill", color: Theme.weight, unit: "kg", values: weight) {
                    weightChart(weight)
                }
                Section {
                    let workouts = data.reduce(0) { $0 + $1.workoutCount }
                    let minutes = data.reduce(0.0) { $0 + $1.workoutMinutes }
                    Label {
                        Text("\(workouts) séance\(workouts > 1 ? "s" : "") · \(Int(minutes)) min actives")
                            .font(Theme.number(.body))
                    } icon: {
                        Image(systemName: "figure.run").foregroundStyle(Theme.sport)
                    }
                    .cardRow(.top)
                    Text("Charge d’entraînement : non calculée dans cette version.")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                        .cardRow(.bottom)
                        .id(Capture.endID)
                } header: { SectionTitle("Activité") }
            }
            .themedList()
            .scrollsToEndForCapture()
            .navigationTitle("Tendances")
        }
    }

    @ViewBuilder private func trendSection<C: View>(title: String, systemImage: String, color: Color, unit: String, values: [TrendPoint], @ViewBuilder chart: () -> C) -> some View {
        Section {
            if values.isEmpty {
                EmptyCard(title: "Pas encore de données", systemImage: systemImage, description: "Les données Apple Health apparaîtront ici après synchronisation.")
                    .cardRow()
            } else {
                VStack(alignment: .leading, spacing: Theme.spacing(2)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Moyenne des jours renseignés")
                            .font(.caption).foregroundStyle(Theme.inkSoft)
                        Text("\(average(values).formatted(.number.precision(.fractionLength(1)))) \(unit)")
                            .font(Theme.number(.title2))
                    }
                    chart()
                        .themedChartAxes()
                        .frame(height: 150)
                }
                .padding(.vertical, Theme.spacing(1))
                .cardRow()
            }
        } header: {
            Label {
                Text(title).foregroundStyle(Theme.inkSoft)
            } icon: {
                Image(systemName: systemImage).foregroundStyle(color)
            }
        }
    }

    /// Une barre par nuit renseignée : une nuit manquante reste un espace vide.
    private func sleepChart(_ values: [TrendPoint]) -> some View {
        Chart {
            ForEach(values) { point in
                BarMark(x: .value("Jour", point.day, unit: .day), y: .value("Sommeil", point.value))
                    .foregroundStyle(Theme.sleep)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous))
            }
            RuleMark(y: .value("Repère", 8))
                .foregroundStyle(Theme.inkSoft)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .accessibilityLabel("Repère 8 h")
        }
    }

    private func weightChart(_ values: [TrendPoint]) -> some View {
        Chart(segmented(values, maxGapDays: 7)) { point in
            // La courbe s'interrompt après une semaine sans pesée.
            LineMark(x: .value("Jour", point.day), y: .value("Poids", point.value), series: .value("Segment", point.segment))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Theme.weight)
            PointMark(x: .value("Jour", point.day), y: .value("Poids", point.value))
                .foregroundStyle(Theme.weight)
        }
        .chartYScale(domain: .automatic(includesZero: false))
    }

    private func segmented(_ values: [TrendPoint], maxGapDays: Int) -> [TrendPoint] {
        var segment = 0
        var previous: Date?
        return values.sorted { $0.day < $1.day }.map { point in
            if let previous, LivasideDate.calendar.dateComponents([.day], from: previous, to: point.day).day ?? 0 > maxGapDays {
                segment += 1
            }
            previous = point.day
            var point = point
            point.segment = segment
            return point
        }
    }

    private func average(_ values: [TrendPoint]) -> Double {
        values.reduce(0) { $0 + $1.value } / Double(values.count)
    }
}

private struct TrendPoint: Identifiable {
    let day: Date
    let value: Double
    var segment = 0
    var id: Date { day }
}

private struct EmptyCard: View {
    let title: String
    let systemImage: String
    let description: String
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description).foregroundStyle(Theme.inkSoft)
        }
    }
}

private struct MetricRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    let detail: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 24)
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Text(value).font(Theme.number(.title2))
        }
    }
}

private func hours(_ value: Double?) -> String {
    guard let value else { return "—" }
    let whole = Int(value)
    return "\(whole) h \(Int((value - Double(whole)) * 60).formatted(.number.precision(.integerLength(2))))"
}
private func kilograms(_ value: Double?) -> String {
    guard let value else { return "—" }
    return "\(value.formatted(.number.precision(.fractionLength(1)))) kg"
}
private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
