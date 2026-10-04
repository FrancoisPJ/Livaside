import Charts
import SwiftData
import SwiftUI

struct LivasideRootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Aujourd’hui", systemImage: "sun.max.fill") }
            AddMealView()
                .tabItem { Label("Ajouter", systemImage: "plus.circle.fill") }
            TrendsView()
                .tabItem { Label("Tendances", systemImage: "chart.xyaxis.line") }
        }
        .tint(.green)
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
                                .foregroundStyle(.secondary)
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
                    if demoMode {
                        Label("Mode démo : données fictives", systemImage: "theatermasks.fill")
                            .font(.caption).foregroundStyle(.orange)
                    } else if let problem = health.problem {
                        Text(problem).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Sommeil") {
                    MetricRow(icon: "bed.double.fill", title: "Cette nuit", value: hours(today?.sleepHours), detail: today?.sleepHours == nil ? "Aucune donnée de sommeil reçue" : "Durée de sommeil")
                }

                Section("Activité") {
                    MetricRow(icon: "figure.run", title: "Séances aujourd’hui", value: "\(today?.workoutCount ?? 0)", detail: workoutDetail)
                }

                Section("Poids") {
                    MetricRow(icon: "scalemass.fill", title: "Dernière mesure", value: kilograms(latestWeighIn?.weightKg), detail: weightDetail)
                }

                Section("Repas") {
                    if todayMeals.isEmpty {
                        ContentUnavailableView("Aucun repas enregistré", systemImage: "fork.knife", description: Text("Ajoutez un repas en quelques secondes."))
                    } else {
                        ForEach(todayMeals) { meal in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(meal.name)
                                    Text(time(meal.date)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(meal.calories) kcal").foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.delete(todayMeals[index]) }
                            try? modelContext.save()
                        }
                        Text("Total : \(todayMeals.reduce(0) { $0 + $1.calories }) kcal")
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
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
                Section("Le minimum pour l’enregistrer") {
                    TextField("Ex. Yaourt et granola", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .focused($focus, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focus = .calories }
                    TextField("Calories", text: $calories)
                        .keyboardType(.numberPad)
                        .focused($focus, equals: .calories)
                    DatePicker("Heure", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                if !recentMeals.isEmpty {
                    Section("Récents") {
                        ForEach(recentMeals) { meal in
                            Button { reuse(meal) } label: {
                                HStack {
                                    Text(meal.name).foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(meal.calories) kcal").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section("Macros (facultatif)") {
                    macroField("Protéines", value: $protein)
                    macroField("Glucides", value: $carbs)
                    macroField("Lipides", value: $fat)
                }
                if let lastSaved {
                    Label("\(lastSaved) enregistré", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .navigationTitle("Ajouter un repas")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save)
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Enregistrer", action: save).disabled(!canSave)
                }
            }
            .onAppear {
                // L'onglet reste en mémoire : sans ça, un repas saisi à midi garderait l'heure du matin.
                date = .now
                lastSaved = nil
                focus = .name
            }
        }
    }

    @ViewBuilder private func macroField(_ label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: value).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
            Text("g").foregroundStyle(.secondary)
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
    @State private var range = 7

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
                }
                trendSection(title: "Sommeil", systemImage: "bed.double.fill", unit: "h", maxGapDays: 1, values: data.compactMap { snapshot in snapshot.sleepHours.map { TrendPoint(day: snapshot.day, value: $0) } })
                trendSection(title: "Poids", systemImage: "scalemass.fill", unit: "kg", maxGapDays: 7, values: data.compactMap { snapshot in snapshot.weightKg.map { TrendPoint(day: snapshot.day, value: $0) } })
                Section("Activité") {
                    let workouts = data.reduce(0) { $0 + $1.workoutCount }
                    let minutes = data.reduce(0.0) { $0 + $1.workoutMinutes }
                    Label("\(workouts) séance\(workouts > 1 ? "s" : "") · \(Int(minutes)) min actives", systemImage: "figure.run")
                    Text("Charge d’entraînement : non calculée dans cette version.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Tendances")
        }
    }

    @ViewBuilder private func trendSection(title: String, systemImage: String, unit: String, maxGapDays: Int, values: [TrendPoint]) -> some View {
        Section(title) {
            if values.isEmpty {
                ContentUnavailableView("Pas encore de données", systemImage: systemImage, description: Text("Les données Apple Health apparaîtront ici après synchronisation."))
            } else {
                Chart(segmented(values, maxGapDays: maxGapDays)) { point in
                    // La courbe s'interrompt sur un trou : une nuit manquante, ou une semaine sans pesée.
                    LineMark(x: .value("Jour", point.day), y: .value(title, point.value), series: .value("Segment", point.segment))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.green)
                    PointMark(x: .value("Jour", point.day), y: .value(title, point.value))
                        .foregroundStyle(.green)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 150)
                Text("Moyenne des jours renseignés : \(average(values).formatted(.number.precision(.fractionLength(1)))) \(unit)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
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

private struct MetricRow: View {
    let icon: String
    let title: String
    let value: String
    let detail: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.green).frame(width: 24)
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(value).font(.headline.monospacedDigit())
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
