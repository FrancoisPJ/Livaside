import SwiftUI
import Charts

/// 1. Journal du jour (Main View for Alimentation Tab)
struct AlimentationMainView: View {
    @State private var showingAddNote = false
    @State private var showingSearch = false
    
    var body: some View {
        NavigationStack {
            List {
                // Repères facultatifs (Écart affiché sans jugement ni rouge)
                Section {
                    VStack(spacing: Theme.spacing(2)) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Calories")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.inkSoft)
                                Text("1850 / 2200 kcal")
                                    .font(Theme.number(.headline))
                                    .foregroundStyle(Theme.ink)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Écart")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.inkSoft)
                                Text("-350 kcal") // Pas de rouge, reste neutre
                                    .font(Theme.number(.headline))
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                        
                        // Barres pour P/G/L
                        HStack(spacing: Theme.spacing(1)) {
                            MacroBar(title: "Pro", current: 80, goal: 120, color: Theme.nutrition)
                            MacroBar(title: "Glu", current: 150, goal: 200, color: Theme.sport) // reused colors for aesthetics
                            MacroBar(title: "Lip", current: 45, goal: 70, color: Theme.sleep)
                            MacroBar(title: "Fib", current: 20, goal: 30, color: Theme.sauge)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .cardRow(.single)
                
                // Boîte "À valider" (Notes de plat)
                Section {
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(Theme.nutrition)
                            VStack(alignment: .leading) {
                                Text("1 repas chiffré par l'IA")
                                    .foregroundStyle(Theme.ink)
                                Text("Assiette de pâtes carbo au resto")
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            Spacer()
                            Text("Valider")
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.surface)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.nutrition, in: Capsule())
                        }
                    }
                }
                .cardRow(.single)

                // Repas du jour : Matin
                Section(header: SectionTitle("Matin")) {
                    FoodRow(name: "Flocons d'avoine", quantity: "40 g", kcal: 150)
                        .cardRow(.top)
                    FoodRow(name: "Lait demi-écrémé", quantity: "200 ml", kcal: 94)
                        .cardRow(.middle)
                    Button(action: { showingSearch = true }) {
                        Label("Ajouter", systemImage: "plus")
                            .foregroundStyle(Theme.nutrition)
                    }
                    .cardRow(.bottom)
                }

                // Repas du jour : Midi
                Section(header: SectionTitle("Midi")) {
                    FoodRow(name: "Poulet rôti", quantity: "150 g", kcal: 250)
                        .cardRow(.top)
                    FoodRow(name: "Haricots verts", quantity: "200 g", kcal: 60)
                        .cardRow(.middle)
                    Button(action: { showingAddNote = true }) {
                        Label("Note de plat rapide", systemImage: "pencil")
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .cardRow(.middle)
                    Button(action: { showingSearch = true }) {
                        Label("Ajouter", systemImage: "plus")
                            .foregroundStyle(Theme.nutrition)
                    }
                    .cardRow(.bottom)
                }
            }
            .themedList()
            .navigationTitle("Aujourd'hui")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {}) {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Theme.ink)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .disabled(true) // On today, can't go forward
                }
            }
        }
    }
}

/// Composant pour les barres de macros
struct MacroBar: View {
    let title: String
    let current: Double
    let goal: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(Theme.inkSoft)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line).frame(height: 6)
                    Capsule().fill(color)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(current / goal))), height: 6)
                }
            }
            .frame(height: 6)
            Text("\(Int(current))g").font(Theme.number(.caption2)).foregroundStyle(Theme.ink)
        }
    }
}

/// Composant pour un aliment dans la liste
struct FoodRow: View {
    let name: String
    let quantity: String
    let kcal: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name).foregroundStyle(Theme.ink)
                Text(quantity).font(.subheadline).foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Text("\(kcal) kcal").font(Theme.number(.subheadline)).foregroundStyle(Theme.ink)
        }
    }
}

/// 2. Recherche Unique & Scan
struct AlimentationSearchView: View {
    @State private var query = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundStyle(Theme.ink)
                            Text("Scanner un produit")
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
                .cardRow(.single)
                
                if query.isEmpty {
                    Section(header: SectionTitle("Mes Récents")) {
                        FoodRow(name: "Pomme", quantity: "1 pièce (150 g)", kcal: 80).cardRow(.top)
                        FoodRow(name: "Pain de mie complet", quantity: "2 tranches", kcal: 140).cardRow(.bottom)
                    }
                } else {
                    Section(header: SectionTitle("Résultats")) {
                        SearchResultRow(name: "Banane", subtitle: "CIQUAL", defaultKcal: "90 kcal / 100g")
                            .cardRow(.top)
                        SearchResultRow(name: "Banane plantain", subtitle: "CIQUAL", defaultKcal: "122 kcal / 100g")
                            .cardRow(.middle)
                        SearchResultRow(name: "Ma banane écrasée", subtitle: "Mon aliment", defaultKcal: "90 kcal / 100g")
                            .cardRow(.bottom)
                    }
                }
            }
            .themedList()
            .searchable(text: $query, prompt: "Aliment, plat ou marque")
            .navigationTitle("Ajouter (Matin)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SearchResultRow: View {
    let name: String
    let subtitle: String
    let defaultKcal: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name).foregroundStyle(Theme.ink)
                Text(subtitle).font(.caption).foregroundStyle(Theme.nutrition)
            }
            Spacer()
            Text(defaultKcal).font(.caption).foregroundStyle(Theme.inkSoft)
        }
    }
}

/// Modal Choix Quantité (apparaît après avoir tapé un résultat)
struct AlimentationQuantityView: View {
    var body: some View {
        VStack(spacing: Theme.spacing(3)) {
            Text("Banane")
                .font(Theme.titleFont(size: 22))
                .foregroundStyle(Theme.ink)
            
            HStack(spacing: Theme.spacing(2)) {
                QuantityButton(title: "1 portion", subtitle: "120 g")
                QuantityButton(title: "Personnalisé", subtitle: "en grammes", isSelected: false)
            }
            
            Button("Ajouter (108 kcal)") { }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.nutrition)
                .foregroundStyle(Theme.surface)
                .clipShape(Capsule())
        }
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .padding()
    }
}

struct QuantityButton: View {
    let title: String
    let subtitle: String
    var isSelected: Bool = true
    
    var body: some View {
        VStack {
            Text(title).font(.headline).foregroundStyle(isSelected ? Theme.surface : Theme.ink)
            Text(subtitle).font(.caption).foregroundStyle(isSelected ? Theme.surface.opacity(0.8) : Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(isSelected ? Theme.nutrition : Theme.line)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// 3. Scan & Fiche Produit
struct AlimentationScannerView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Text("Placez le code-barres dans le cadre")
                    .foregroundStyle(.white)
                    .padding()
                
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Theme.nutrition, lineWidth: 2)
                    .frame(height: 200)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Bottom sheet produit scanné
                VStack(alignment: .leading, spacing: Theme.spacing(2)) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Pâtes au blé complet")
                                .font(.headline)
                            Text("Barilla")
                                .foregroundStyle(Theme.inkSoft)
                        }
                        Spacer()
                        Text("Nutri-Score A") // Simplified visually for mockup
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Theme.sauge.opacity(0.2))
                            .foregroundStyle(Theme.sauge)
                            .clipShape(Capsule())
                    }
                    Text("350 kcal / 100g")
                        .font(Theme.number(.subheadline))
                        .foregroundStyle(Theme.ink)
                    
                    Button("Continuer") { }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.nutrition)
                        .foregroundStyle(Theme.surface)
                        .clipShape(Capsule())
                }
                .padding()
                .background(Theme.surface)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Theme.radius, topTrailingRadius: Theme.radius))
            }
        }
    }
}

/// 4. Mes Aliments & Plats
struct AlimentationMyFoodsView: View {
    @State private var selection = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Type", selection: $selection) {
                    Text("Favoris").tag(0)
                    Text("Mes plats").tag(1)
                    Text("Mes aliments").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Theme.bg)
                
                List {
                    Section {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "doc.on.clipboard")
                                    .foregroundStyle(Theme.ink)
                                Text("Copier le repas d'hier")
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                    }
                    .cardRow(.single)
                    
                    Section(header: SectionTitle("Plats composés")) {
                        FoodRow(name: "Porridge matinal", quantity: "1 portion", kcal: 450).cardRow(.top)
                        FoodRow(name: "Bolo maison", quantity: "1 assiette", kcal: 620).cardRow(.bottom)
                    }
                }
                .themedList()
            }
            .navigationTitle("Mes éléments")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// 5. Note de plat (Saisie rapide avec IA)
struct AlimentationMealNoteView: View {
    @State private var note = "Assiette de pâtes carbo au resto, grosse portion"
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextEditor(text: $note)
                        .frame(height: 100)
                        .padding(.vertical, -4)
                }
                .cardRow(.single)
                
                Section {
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "camera")
                                .foregroundStyle(Theme.ink)
                            Text("Ajouter une photo (facultatif)")
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
                .cardRow(.single)
                
                Section {
                    HStack(alignment: .top) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Theme.inkSoft)
                        Text("La note sera envoyée en attente. Votre IA analysera le plat et proposera les valeurs nutritionnelles.")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .themedList()
            .navigationTitle("Note de plat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {}
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.nutrition)
                }
            }
        }
    }
}

/// PREVIEWS
#Preview("1. Journal & Repères") {
    AlimentationMainView()
}

#Preview("2. Recherche Unique") {
    AlimentationSearchView()
}

#Preview("2b. Choix Quantité") {
    AlimentationQuantityView()
}

#Preview("3. Scan") {
    AlimentationScannerView()
}

#Preview("4. Mes Aliments") {
    AlimentationMyFoodsView()
}

#Preview("5. Note de plat") {
    AlimentationMealNoteView()
}
