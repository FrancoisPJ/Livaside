<!-- Source : Paperclip LIV-2, document `spec` -->

# Spec MVP suivi — Livaside

**Statut :** décisions arrêtées. Ce document est la référence technique du MVP. Il n'y a pas d'option
ouverte dedans : tout ce qui est écrit ici est tranché, et ce qui n'y est pas est hors périmètre.

**Révision du 2026-10-04 (LIV-9).** Les 5 contraintes de modèle de données du document
`architecture` de LIV-4 sont **acceptées**, avec trois amendements techniques et un conflit de
périmètre remonté au CEO. Sections touchées : **D9 révisé**, **D16–D18 ajoutés**, **§3.0** (champs
communs), **§3.1–3.4**, **§4** (fuseau d'un échantillon HealthKit), **§6 réécrit**, §7, §8, §9.
Coût net : ~1,5 jour, dont 1 pour le sérialiseur JSON.

**Objectif de l'étape :** une app iOS qui tourne sur l'iPhone du fondateur, importe automatiquement
sommeil / séances / poids depuis Apple Santé, permet de logger un repas en moins de 15 secondes, et
montre des tendances sur 7 et 30 jours. Trois écrans : **Aujourd'hui**, **Ajouter un repas**,
**Tendances**.

---

## 1. Décisions arrêtées

| # | Décision | Pourquoi (une ligne) |
|---|---|---|
| D1 | **iOS 17.0 minimum**, SwiftUI, Swift Charts | SwiftData, `@Observable` et Swift Charts y sont tous disponibles sans `@available` dispersés dans le code. |
| D2 | **Stockage 100 % local, SwiftData**, pas de CloudKit, pas d'App Group | Aucune donnée de santé ne quitte l'iPhone : c'est la version la plus simple à construire *et* la plus facile à défendre. |
| D3 | **Aucun compte utilisateur**, aucune authentification, aucune entité `User` | Rien à inscrire, rien à retenir : l'identité, c'est l'appareil. |
| D4 | **Lecture seule d'Apple Santé** — l'app n'écrit aucune donnée dans Santé en v1 | Demander le droit d'écriture sans écrire est un signal négatif en revue App Store, et la démo n'en a pas besoin. |
| D5 | **Autorisations demandées une seule fois**, depuis un écran d'accueil dédié, pour exactement 8 types (§4) | Une liste courte et expliquée se lit ; une liste longue se refuse. |
| D6 | **Pas de livraison en arrière-plan** (`enableBackgroundDelivery` non utilisé) : synchro au premier plan | Supprime toute une classe de pannes invisibles ; conséquence assumée : les données sont à jour à chaque ouverture de l'app, pas en continu. |
| D7 | **Apple Santé est la source de vérité** pour sommeil, séances, poids, mesures. SwiftData n'en garde qu'un **miroir reconstructible**. | Un miroir jetable peut être resynchronisé sans migration ni perte : les seules données précieuses sont les repas. |
| D8 | **Aucune relation SwiftData en v1** : tout se joint par jour (`dayKey`) | Les miroirs sont effacés/recréés à la synchro ; une relation vers un miroir crée des références mortes. |
| D9 | **Aucune table d'agrégats persistée** : les agrégats journaliers sont un **type valeur** (`DailySummary`, une `struct`, pas un `@Model`) produit à la volée par `TrendsCalculator` | 30 jours de données, c'est quelques centaines de lignes. Une table persistée ajouterait un problème d'invalidation (le sommeil se recalcule sur ±1 jour, les séances se regroupent rétroactivement) — exactement la divergence silencieuse qu'on veut éviter. Même forme, même définition, zéro cache à invalider. |
| D10 | **Unités canoniques SI en base** (secondes, kg, m, kcal), formatage à l'affichage selon la locale | Une seule convention en base : pas d'ambiguïté pour l'UI aujourd'hui ni pour le MCP demain. |
| D11 | **Saisie nutrition manuelle**, texte libre + macros optionnelles | Une base alimentaire est un projet à elle seule ; le pari du MVP est que la saisie rapide suffit. |
| D12 | **Français uniquement**, chaînes en dur (pas de catalogue de chaînes) | La localisation est un travail mécanique à faire plus tard, pas un risque technique. |
| D13 | **Aucune dépendance tierce**, un seul projet Xcode, une seule cible app | Rien à maintenir, rien à auditer, build reproductible. |
| D14 | **Installation par Xcode sur l'iPhone du fondateur**, pas de TestFlight ni d'App Store | Le périmètre s'arrête à la démo ; toute publication passe par une décision explicite du CEO. |
| D15 | **Jeu de données de démo en `#if DEBUG`** | Le simulateur n'a aucune donnée Santé : sans ça, ni le design ni les graphiques ne sont testables, et la démo n'a pas de filet. |
| D16 | **Identifiant `uid: String` déterministe et stable à la reconstruction** sur chaque entité, + provenance en champs plats (`sourceRaw`, `sourceBundleID`) | Validé en LIV-9 (C1). Un UUID aléatoire régénéré à chaque reconstruction du miroir rendrait toute synchro future non idempotente — l'inverse du but. Détail et dérivation par entité en §3. |
| D17 | **`timeZoneID` stocké sur tout enregistrement horodaté**, avec `timeZoneIsExact: Bool` | Validé en LIV-9 (C2). Le fuseau au moment de l'événement est la seule information de ce document **non récupérable a posteriori**. Le booléen existe parce que HealthKit ne le fournit pas toujours (§4). |
| D18 | **Sérialiseur JSON complet et versionné (`schema_version`) livré en v1**, structures `Codable` distinctes des `@Model` | Validé en LIV-9 (C5). Un seul artefact pour trois promesses : export utilisateur (LIV-5), format de synchro future, MCP local. Les DTO sont séparés des entités pour ne pas coupler la persistance au format de sortie. |

### Conséquences à connaître

- **D3 + D2 :** réinstaller l'app efface les repas saisis. Les données venant de Santé se
  réimportent toutes seules (D7), les repas non. Le fichier SwiftData vit dans
  `Application Support`, donc il **est** inclus dans la sauvegarde iCloud de l'appareil : un
  changement d'iPhone ne perd rien, une désinstallation si.
- **D6 :** la phrase à tenir côté produit est « à jour dès que vous ouvrez l'app », pas « en temps
  réel ».
- **D4 :** les repas saisis dans Livaside n'apparaissent pas dans Apple Santé en v1.

---

## 2. Périmètre des trois écrans

Navigation : `TabView` à deux onglets — **Aujourd'hui**, **Tendances**. *Ajouter un repas* est une
feuille modale, pas un onglet.

### 2.1 Aujourd'hui

En-tête : date du jour, et une ligne discrète « mis à jour il y a X ». `refreshable` déclenche une
resynchro HealthKit.

Quatre cartes, dans cet ordre :

1. **Sommeil — nuit dernière**
   - Durée de sommeil (h min), heure de coucher → heure de lever.
   - Répartition des phases (profond / core / REM / éveillé) **si la source les fournit**, sinon rien
     — pas de barre vide, pas d'estimation.
   - Delta par rapport à la moyenne des 7 dernières nuits (`+32 min`, `−18 min`).
2. **Entraînement — aujourd'hui**
   - Liste des séances du jour : type, durée, kcal actives si disponibles.
   - Une ligne de contexte : minutes cumulées sur les 7 derniers jours.
3. **Poids**
   - Dernière mesure + date de cette mesure (« 74,2 kg · il y a 3 jours ») — la date est obligatoire,
     le poids est une donnée éparse par nature.
   - Delta sur 7 jours, calculé entre moyennes glissantes et non entre deux points bruts.
4. **Nutrition — aujourd'hui**
   - Total kcal du jour, puis protéines / glucides / lipides.
   - Liste des repas saisis aujourd'hui (moment, nom, kcal), tap = édition.
   - Bouton d'ajout, l'élément le plus visible de l'écran.

Hors de cet écran : objectifs, scores, badges, séries (« streaks »), notifications, conseils,
coaching, pas (step count), fréquence cardiaque.

### 2.2 Ajouter un repas

Feuille modale ouverte depuis la carte Nutrition. Objectif mesurable : **repas récurrent en ≤ 3 taps,
repas nouveau en ≤ 15 s** (nom + kcal).

- **Raccourci « récents »** en haut : 5 repas distincts les plus fréquents parmi les 30 derniers
  jours. Un tap préremplit nom + moment + macros ; tout reste éditable. C'est le chemin des 3 taps.
- **Champs :** nom (texte libre, **seul champ obligatoire**), moment (segmenté : petit-déjeuner /
  déjeuner / dîner / collation, présélectionné selon l'heure), kcal, protéines, glucides, lipides.
- **Date et heure :** maintenant par défaut, modifiables (permet de rattraper un repas oublié).
- Focus automatique sur le nom à l'ouverture, clavier décimal sur les champs numériques,
  « Enregistrer » toujours atteignable au-dessus du clavier.
- **Validation :** nom non vide, c'est tout. Un repas sans macros compte dans la liste mais pas dans
  les totaux, et s'affiche « — », **jamais 0**.
- Même écran pour modifier ; suppression par balayage dans la liste et par un bouton en bas de
  l'écran d'édition.

Hors de cet écran : scan de code-barres, photo, base alimentaire, portions et unités (« 1 bol »),
recettes, repas composés, suivi de l'eau, import de repas depuis Santé.

### 2.3 Tendances

Sélecteur **7 jours / 30 jours** en haut, persistant entre les lancements.

Quatre graphiques, chacun avec une valeur de résumé au-dessus et une mention explicite de couverture
(« 5/7 nuits renseignées ») dès qu'il manque un jour :

| Graphique | Représentation | Résumé affiché |
|---|---|---|
| Sommeil | Barres, heures par nuit, ligne horizontale de moyenne | Moyenne sur la période + delta vs période précédente |
| Poids | Points aux mesures réelles + moyenne glissante 7 jours | Dernier poids + variation sur la période |
| Volume d'entraînement | Barres, minutes par jour (en 30 j : agrégées par semaine) | Minutes totales + nombre de séances |
| Calories ingérées | Barres, kcal par jour (repas saisis) | Moyenne par jour renseigné |

**Règle des trous, valable partout : une donnée absente n'est jamais un zéro.** Pas de barre, pas de
point, pas d'interpolation. Les moyennes sont calculées sur les jours renseignés uniquement, et la
couverture est affichée. Pour le poids, la ligne relie les points consécutifs sauf si plus de 14
jours les séparent, auquel cas elle est coupée.

Hors de cet écran : périodes personnalisées, corrélations entre métriques, export d'image, scores de
récupération, comparaison à des normes de population, phases de sommeil en graphique empilé.

---

## 3. Modèle de données SwiftData

Six entités, aucune relation (D8). Chaque entité porte un `dayKey: String` au format `yyyy-MM-dd`
calculé **dans le calendrier de l'utilisateur au moment de l'insertion** — regrouper par jour local à
la volée depuis une `Date` devient faux dès qu'on change de fuseau.

### 3.0 Champs communs (D16, D17)

Tout enregistrement de données porte ce socle. Il vient de la validation des contraintes C1 et C2 de
LIV-4 (voir LIV-9 pour les arbitrages).

```
uid: String               // .unique — déterministe, stable à la reconstruction du miroir
sourceRaw: String         // "healthKit" | "manual" | "derived"
sourceBundleID: String?   // non nil si sourceRaw == "healthKit"
sourceName: String?       // libellé lisible de la source, figé à l'import
dayKey: String            // jour local d'attribution, "yyyy-MM-dd"
timeZoneID: String        // "Europe/Paris" — fuseau de l'événement
timeZoneIsExact: Bool     // false => déduit de l'appareil à l'import, pas de l'échantillon
createdAt: Date           // première insertion locale
updatedAt: Date           // ne bouge QUE si le contenu a changé
lastSyncedAt: Date?       // dernier passage de la synchro, même sans changement
```

**`uid` est dérivé, jamais aléatoire** — c'est l'amendement apporté à C1. Un `UUID()` tiré au hasard
serait régénéré à chaque reconstruction du miroir (D7) et rendrait toute synchro future non
idempotente : exactement le bug que la contrainte cherche à éviter. Dérivation par entité :

| Entité | `uid` | Stable parce que |
|---|---|---|
| `SleepNight` | `"sleep:" + dayKey` | l'agrégat n'a pas d'UUID HealthKit ; sa clé d'identité **est** la nuit |
| `WorkoutRecord` | `"workout:" + healthKitUUID` | l'UUID vient de HealthKit et survit à la reconstruction |
| `BodyMeasurement` | `"body:" + kindRaw + ":" + healthKitUUID` | idem |
| `Meal` | `"meal:" + id` | créé une fois, jamais reconstruit — un UUID aléatoire est ici correct |

**`updatedAt` vs `lastSyncedAt`** — deux champs, deux rôles, et c'est le point à ne pas rater. La
synchro repasse sur les mêmes échantillons à chaque ouverture de l'app : si `updatedAt` bougeait à
chaque passage, « tout ce qui a changé depuis X » renverrait le miroir entier et le différentiel ne
voudrait plus rien dire. L'import compare donc le contenu avant d'écrire, et ne touche `updatedAt`
qu'en cas de changement réel. `lastSyncedAt` reste pour le diagnostic.

**`deletedAt` n'existe que sur `Meal`** (§3.4) — second amendement à C1, justifié en §6.

### Provenance

| Entité | Origine | Reconstructible ? |
|---|---|---|
| `SleepNight` | Apple Santé (agrégé) | Oui |
| `WorkoutRecord` | Apple Santé | Oui |
| `BodyMeasurement` | Apple Santé | Oui |
| `Meal` | **Saisie utilisateur** | **Non — seule donnée précieuse** |
| `HealthSyncState` | Interne (curseurs de synchro) | Oui |
| `AppPreferences` | Interne | Oui |

### 3.1 `SleepNight` — une ligne par nuit, agrégée

Socle §3.0, plus (`dayKey` = jour du **réveil**, et c'est lui qui porte `@Attribute(.unique)` via
`uid`) :

```
bedtime: Date               // début de la nuit retenue (instant absolu)
wakeTime: Date              // fin de la nuit retenue (instant absolu)
timeInBedSeconds: Double
timeAsleepSeconds: Double?  // nil si la source ne distingue pas sommeil et lit
coreSeconds: Double?
deepSeconds: Double?
remSeconds: Double?
awakeSeconds: Double?
hasStages: Bool             // false => l'UI n'affiche aucune répartition
competingSourceCount: Int   // nb de sources écartées, pour le diagnostic
sampleCount: Int
```

`sourceBundleID` / `sourceName` du socle désignent ici **la source retenue** pour la nuit (§5.1).
`timeZoneID` est celui de l'échantillon de réveil — c'est le fuseau où l'utilisateur s'est levé, donc
celui qui justifie le `dayKey`.

### 3.2 `WorkoutRecord` — une ligne par séance HealthKit

Socle §3.0, plus :

```
healthKitUUID: UUID         // identité d'origine, source du uid
startDate: Date
endDate: Date
durationSeconds: Double     // HKWorkout.duration (exclut les pauses), pas end - start
activityTypeRaw: UInt       // HKWorkoutActivityType.rawValue
activityName: String        // libellé français figé à l'import
activeEnergyKcal: Double?
duplicateGroupKey: String?  // non nil si la séance a été regroupée (§5.2)
isGroupRepresentative: Bool // seul le représentant compte dans le volume
```

### 3.3 `BodyMeasurement` — une ligne par échantillon

Une seule entité pour poids et mesures : ajouter une mesure devient une valeur d'enum, pas une
table.

Socle §3.0, plus :

```
healthKitUUID: UUID         // identité d'origine, source du uid
date: Date                  // instant absolu de la mesure
kindRaw: String             // "bodyMass" | "bodyFatPercentage" | "leanBodyMass"
                            // | "waistCircumference" | "height"
value: Double               // SI : kg, fraction 0–1, kg, m, m
```

L'IMC n'est **pas** lu depuis Santé : il est calculé (`bodyMass / height²`) pour rester toujours
cohérent avec le poids affiché.

### 3.4 `Meal` — saisie utilisateur

Socle §3.0 (avec `sourceRaw = "manual"`, `timeZoneIsExact = true` — le repas est saisi là où
l'utilisateur se trouve), plus :

```
id: UUID                    // source du uid
consumedAt: Date            // instant absolu
mealTypeRaw: String         // "breakfast" | "lunch" | "dinner" | "snack"
name: String                // obligatoire, non vide
energyKcal: Double?
proteinGrams: Double?
carbGrams: Double?
fatGrams: Double?
notes: String?
deletedAt: Date?            // suppression logique — UNIQUEMENT ici
```

`deletedAt` n'existe que sur cette entité, et c'est délibéré. `Meal` est la seule donnée **non
reconstructible** (D7) : une suppression définitive y est irrécupérable pour une synchro future. Les
miroirs, eux, se reconstruisent depuis Apple Santé — y poser des pierres tombales ferait grossir la
base indéfiniment, obligerait chaque requête à filtrer `deletedAt == nil`, et ne garantirait rien de
plus (une reconstruction du miroir efface les pierres tombales avec le reste). Le raisonnement
complet est en §6.

Toute requête sur `Meal` filtre `deletedAt == nil`. La suppression définitive des lignes effacées
n'est pas au périmètre v1.

### 3.5 `HealthSyncState` — curseurs de synchro

`@Attribute(.unique) typeIdentifier`. Une ligne par type HealthKit lu.

```
typeIdentifier: String      // .unique
anchorData: Data?           // HKQueryAnchor sérialisé
lastSuccessAt: Date?
lastErrorMessage: String?
```

### 3.6 `AppPreferences` — une seule ligne

```
id: UUID                    // .unique, toujours la même valeur
trendsRangeDays: Int        // 7 ou 30
hasCompletedOnboarding: Bool
healthAuthorizationRequestedAt: Date?
```

### Note d'implémentation

Si `@Attribute(.unique)` se révèle capricieux sur iOS 17.0 (l'upsert sur conflit y a des angles
morts connus), la parade est un `FetchDescriptor` par UUID avant insertion. L'import reste
idempotent dans les deux cas — c'est la propriété à préserver, pas le mécanisme.

---

## 4. Types HealthKit lus

**Huit types, en lecture seule, demandés en une seule fois.** Rien d'autre n'est demandé.

| Type HealthKit | Usage | Unité en base |
|---|---|---|
| `HKCategoryType(.sleepAnalysis)` | Durée et phases de sommeil | secondes |
| `HKObjectType.workoutType()` | Séances : type, durée | secondes |
| `HKQuantityType(.activeEnergyBurned)` | kcal d'une séance, **via `workout.statistics(for:)` uniquement** — jamais en requête globale | kcal |
| `HKQuantityType(.bodyMass)` | Poids | kg |
| `HKQuantityType(.bodyFatPercentage)` | Masse grasse | fraction 0–1 |
| `HKQuantityType(.leanBodyMass)` | Masse maigre | kg |
| `HKQuantityType(.waistCircumference)` | Tour de taille | m |
| `HKQuantityType(.height)` | Taille, pour l'IMC — lue une fois | m |

**Explicitement non lus en v1 :** pas (`stepCount`), fréquence cardiaque, FC de repos, VFC
(`heartRateVariabilitySDNN`), distances (`distanceWalkingRunning` et apparentés), énergie de base,
VO2 max, température, SpO₂, cycles menstruels, données cliniques, ECG, nutrition
(`dietary*`), `bodyMassIndex`.

> **Point d'arbitrage remonté au CEO (non bloquant).** Un indicateur de récupération crédible
> demande la FC de repos et la VFC. Les deux sont lisibles et peu coûteuses, mais elles n'existent
> dans aucun des trois écrans de la démo : les ajouter serait élargir le périmètre sans décision.
> Je les laisse donc dehors. Le modèle les accueille en une ligne (une valeur d'enum dans
> `BodyMeasurement`, ou une entité `DailyMetric` symétrique) le jour où c'est validé.

### Le fuseau d'un échantillon : ce que HealthKit donne vraiment (D17)

HealthKit **ne garantit pas** le fuseau d'origine. Il vit dans
`HKMetadataKeyTimeZone` (un identifiant IANA), et ce champ n'est rempli que si la source qui a écrit
l'échantillon a pris la peine de le faire : le sommeil Apple Watch le renseigne généralement, les
pesées de balance connectée presque jamais, les sources tierces c'est au cas par cas.

D'où la règle d'import, en deux lignes :

1. `HKMetadataKeyTimeZone` présent → on le stocke, `timeZoneIsExact = true`.
2. Absent → on stocke le fuseau **courant de l'appareil au moment de l'import**, avec
   `timeZoneIsExact = false`.

Le cas 2 est une approximation, et elle est fausse pour un échantillon importé après un voyage. Le
booléen existe pour que personne — ni l'UI, ni un consommateur externe — ne prenne cette valeur pour
une certitude. C'est la version honnête de la contrainte C2 : on stocke le mieux disponible, et on
dit lequel des deux c'est. Pour `Meal`, saisi en direct, le fuseau est toujours exact.

`dayKey` est calculé avec le fuseau retenu, quelle qu'en soit la provenance — jamais avec le fuseau
d'affichage du moment.

### Autorisations : ce qu'iOS permet réellement

1. `HKHealthStore.isHealthDataAvailable()` d'abord. Faux sur iPad et sur certains simulateurs :
   l'app doit rester utilisable pour les repas, les cartes santé affichant un état « Apple Santé
   n'est pas disponible sur cet appareil ».
2. **Point dur à connaître : iOS ne dit pas si une autorisation de *lecture* a été refusée.**
   `authorizationStatus(for:)` n'est fiable que pour l'écriture ; en lecture, un refus est
   indistinguable d'une absence de données. Conséquence directe : **l'app ne doit jamais affirmer
   « accès refusé »**. Le message honnête, quand un type n'a jamais rien renvoyé alors que la
   demande a été faite, est : *« Aucune donnée de sommeil trouvée. Vérifiez le partage dans Santé →
   Profil → Apps. »* avec un bouton qui ouvre `x-apple-health://`.
3. `getRequestStatusForAuthorization(toShare:read:)` sert à savoir si la feuille système
   s'afficherait encore — donc à décider s'il faut (re)demander, **pas** à déduire un refus.
4. `Info.plist` : `NSHealthShareUsageDescription` requis, avec un texte qui dit à quoi ça sert.
   `NSHealthUpdateUsageDescription` **absent** (D4 : on n'écrit rien). Capacité HealthKit activée,
   sans mode d'arrière-plan (D6).
5. L'écran d'accueil explique en une phrase par famille de données *avant* d'ouvrir la feuille
   système. Un utilisateur qui comprend accepte ; un utilisateur surpris refuse, et en lecture un
   refus est irrécupérable sans passer par l'app Santé.

### Mécanique de synchro

- Un `HKAnchoredObjectQuery` par type, avec l'ancre persistée dans `HealthSyncState`. Import
  incrémental, et les suppressions (`deletedObjects`) effacent les lignes miroir correspondantes.
- Déclenchement : au lancement, au retour au premier plan, et au `refreshable`. Plus un
  `HKObserverQuery` actif seulement pendant que l'app est au premier plan.
- Sommeil : à chaque lot reçu, les nuits touchées sont **recalculées entièrement** sur l'intervalle
  `[min(start) − 1 jour, max(end) + 1 jour]`. Agréger en incrémental du sommeil multi-sources est un
  piège ; recalculer est bon marché.
- Premier import : 90 jours d'historique, suffisant pour la vue 30 jours et pour que les tendances
  ne soient pas vides à la première ouverture.

---

## 5. Données manquantes et sources multiples

C'est le vrai risque technique du projet. Les règles ci-dessous sont déterministes : deux imports des
mêmes données donnent le même résultat.

### 5.1 Sommeil — le cas difficile

Plusieurs apps (Apple Watch, AutoSleep, Pillow, Oura, saisie manuelle iPhone) écrivent des
échantillons `sleepAnalysis` qui **se chevauchent**. Les additionner donne des nuits de 14 heures.

1. **Constituer les nuits.** Les échantillons sont groupés en grappes séparées par plus de
   **90 minutes** de vide. Une grappe est retenue comme « la nuit » si son milieu tombe entre 18 h la
   veille et 14 h le jour. Si plusieurs grappes sont éligibles, la plus longue gagne. Les autres sont
   ignorées — **les siestes sont hors périmètre v1**.
2. **Choisir une source unique par nuit.** La source retenue est celle qui apporte le plus de minutes
   de sommeil sur la nuit (égalité : identifiant de bundle en ordre alphabétique, pour la
   stabilité). On n'utilise **que** ses échantillons. Mélanger deux sources, c'est mélanger deux
   modèles de phases incompatibles. Le nombre de sources écartées est conservé dans
   `competingSourceCount` pour le diagnostic.
3. **Calculer par union d'intervalles, jamais par somme.** Même une seule source produit des
   échantillons qui se recouvrent.
   - `timeAsleep` = union des intervalles de valeur `asleepCore`, `asleepDeep`, `asleepREM`,
     `asleepUnspecified`. **C'est la définition qui fait foi**, y compris pour tout consommateur
     externe (§6.3) : une *somme* des stades donne des nuits de 14 heures.
   - `timeInBed` = union des intervalles `inBed` ∪ intervalles de sommeil (certaines sources
     n'écrivent que l'un ou l'autre).
4. **Phases absentes.** Si la source retenue n'écrit que `asleepUnspecified` ou `inBed`,
   `hasStages = false` : l'UI affiche la durée totale et **rien** sur les phases.
5. **`inBed` seul, sans aucun échantillon de sommeil.** `timeAsleep = nil`, et l'écran affiche
   « temps au lit » explicitement libellé comme tel. On n'invente jamais une durée de sommeil.
6. **Aucun échantillon pour une nuit.** Aucune ligne `SleepNight` n'est créée. La carte Aujourd'hui
   affiche « pas de données pour la nuit dernière », le graphique saute la barre.

### 5.2 Séances — doublons entre apps

Deux sources enregistrent souvent la même séance (Apple Watch + Strava).

- Regroupement : deux séances de **même `activityType`** dont les intervalles se recouvrent à plus de
  **50 %** (recouvrement / durée de la plus courte) appartiennent au même groupe
  (`duplicateGroupKey`).
- Représentant du groupe (`isGroupRepresentative = true`) : la plus longue durée ; égalité → la plus
  grande énergie ; égalité → le plus petit UUID.
- **Rien n'est supprimé.** Seul le représentant compte dans le volume d'entraînement et dans les
  listes. Les doublons restent en base, invisibles, prêts à expliquer un écart.

### 5.3 Poids et mesures — plusieurs valeurs le même jour

- Tous les échantillons sont conservés (dédoublonnés par UUID HealthKit).
- Pour l'affichage et les tendances, **une seule valeur par jour et par type** : la plus **récente**
  du jour. Égalité d'horodatage → identifiant de bundle en ordre alphabétique.
- **Aucune moyenne entre sources** : faire la moyenne de deux balances différentes produit un poids
  qui n'existe pas.
- Le poids est éparse par nature : un jour sans pesée n'est pas un problème à signaler. La carte
  affiche toujours la date de la mesure, et la tendance ne dessine un point que là où il y en a un.

### 5.4 Règle générale sur les manques

Trois états distincts à l'écran, jamais confondus :

1. **Donnée présente** → on l'affiche.
2. **Pas de donnée** → un message neutre et court. Pas de zéro, pas de point d'exclamation, pas de
   culpabilisation : « la santé à vos côtés, pas devant vous ».
3. **Apple Santé jamais connecté** (onboarding non fait) → une invitation à connecter, une seule
   fois par carte, sans insistance.

---

## 6. Les 5 contraintes de LIV-4 — statut validé (LIV-9)

Aucun code MCP n'est écrit (hors périmètre, §8). Le mot « MCP » n'apparaît pas dans l'app. Les cinq
contraintes du document `architecture` de LIV-4 sont **acceptées**, avec trois amendements techniques
et un conflit de périmètre remonté. Coût net ajouté à la spec : **~1,5 jour, dont 1 pour C5.**

| | Contrainte | Statut | Coût réel |
|---|---|---|---|
| C1 | Identité, provenance, `updatedAt`, suppression douce | **Accepté, 3 amendements** | ~0,5 j (le `updatedAt` conditionnel) |
| C2 | Instant UTC + fuseau + jour local | **Accepté, 1 précision** | ~0,1 j (1 champ + 1 booléen) |
| C3 | Unités canoniques SI | **Déjà décidé (D10)** | 0 |
| C4 | Définition des agrégats dans la spec | **Accepté, 1 correction + 1 conflit** | 0 (déjà écrit §5) |
| C5 | Sérialiseur JSON versionné | **Accepté** | ~1 j |

### 6.1 Amendements à C1

**(a) `uid` déterministe, pas un `UUID()` aléatoire.** Détaillé en §3.0. La contrainte demande « un
`id: UUID` stable, jamais réattribué ». Sur un miroir reconstructible (D7), un UUID tiré au hasard
est précisément *réattribué* à chaque reconstruction : le même entraînement reviendrait sous une
nouvelle identité et un push futur le dupliquerait. L'identité stable d'un miroir, c'est celle que
HealthKit porte déjà. On la reprend telle quelle, préfixée par type.

**(b) Provenance en champs plats, pas en enum à valeur associée.** `.healthKit(bundleID)` ne se
persiste pas proprement en SwiftData et surtout ne s'utilise pas dans un `#Predicate` — on ne
pourrait plus filtrer par source en base. Deux champs (`sourceRaw: String`, `sourceBundleID: String?`)
donnent la même information, interrogeable. L'enum existe en mémoire, pas en base.

**(c) Suppression douce sur `Meal` seulement.** C'est le seul écart de fond, et il s'appuie sur le
document de LIV-4 lui-même : si le relais est *une réplique dérivée, reconstructible intégralement
par un re-push* (§1.1), alors les miroirs n'ont pas besoin de pierres tombales — leur vérité de
référence est Apple Santé, pas la base locale, et un re-push complet du miroir est toujours correct.
Les volumes le confirment : 90 jours de miroir, c'est quelques centaines de lignes, soit un snapshot
JSON de l'ordre de 200 Ko. Un push incrémental des miroirs optimiserait un problème qui n'existe pas,
au prix d'un `deletedAt == nil` dans chaque requête de l'app.

**Le contrat de synchro qui en découle**, et qui est ce qu'il faut retenir côté relais :

- **Miroirs** (`SleepNight`, `WorkoutRecord`, `BodyMeasurement`) → **snapshot complet**, remplacement
  intégral côté relais. Idempotent par construction, les suppressions se propagent gratuitement.
- **`Meal`** → **différentiel** sur `updatedAt`, avec pierres tombales. C'est la donnée non
  reconstructible, elle seule mérite la mécanique.

### 6.2 Précision sur C2

Acceptée sans réserve sur le fond : le fuseau de l'événement est bien la seule information non
récupérable du document, et c'est ce qui justifie de l'ajouter maintenant. Un point de réalité
HealthKit s'y ajoute : **le fuseau d'origine n'est pas toujours disponible** (§4). D'où le
`timeZoneIsExact: Bool` (D17). On stocke le mieux disponible et on dit lequel c'est — sans quoi un
consommateur externe prendrait une déduction pour une mesure, ce que la règle « jamais un nombre nu »
du §4 de LIV-4 interdit par ailleurs.

`startAt` / `endAt` : les noms de domaine sont conservés en base (`bedtime`/`wakeTime`,
`consumedAt`, `date`) parce qu'ils rendent le code des écrans lisible. **C'est le sérialiseur (C5)
qui normalise** vers `start_at` / `end_at` dans le JSON. Un `Date` Swift est déjà un instant absolu :
l'exigence UTC est satisfaite par construction, pas par une convention à tenir.

### 6.3 C4 — une correction de définition, et un conflit de périmètre

**Correction.** Le document de LIV-4 donne comme exemple « durée de sommeil = somme des stades
`asleep*` ». **Cette définition est fausse sur des données réelles** et elle produit des nuits de 14
heures : même une source unique écrit des échantillons qui se recouvrent. La définition qui fait foi
est celle du **§5.1** : *union des intervalles* des stades `asleepCore`, `asleepDeep`, `asleepREM`,
`asleepUnspecified`, sur la source retenue pour la nuit, rattachée au jour du réveil. C'est
exactement la raison d'être du §5.1, et c'est la définition que le MCP devra reprendre mot pour mot.

Les définitions qui font foi, toutes déjà écrites : sommeil §5.1, dédoublonnage des séances §5.2,
poids et mesures §5.3, règle des trous §5.4 et §2.3.

**Conflit de périmètre : la « charge d'entraînement » n'est pas calculable en v1.** Le document
définit « charge = durée × intensité relative » et `get_readiness_context` annonce une charge 7 j /
28 j. L'intensité relative demande les zones cardiaques ou un RPE : la v1 ne lit **ni l'un ni
l'autre** (§4 — fréquence cardiaque et VFC explicitement hors périmètre, arbitrage CEO ouvert). Ce
que la v1 peut fournir : **minutes actives et nombre de séances par jour**, agrégeables sur 7 et
28 jours. Deux issues possibles, et c'est au CEO de trancher, pas à moi :

1. Le relais expose `active_minutes_7d / 28d` comme indicateur de volume, documenté comme tel, et
   `training_load: null` tant que l'intensité n'existe pas. **Ma recommandation** — coût nul, et
   c'est honnête.
2. On ajoute la FC de repos et la VFC aux types lus. Techniquement une ligne, mais c'est un
   élargissement de périmètre pendant les 4 semaines de la démo, pour une métrique absente des trois
   écrans.

**`DailySummary` : pas de table persistée (D9), un type valeur.** `TrendsCalculator` produit une
`struct DailySummary` — une ligne par jour local, avec les trous explicites. L'écran Tendances
l'affiche, le sérialiseur l'émet, le MCP la recevra telle quelle : la « table toute prête » demandée
existe donc, mais au moment de l'export, pas en base. Raison : le sommeil se recalcule sur une
fenêtre ±1 jour à chaque lot reçu et les séances se regroupent rétroactivement (§5.1, §5.2) — une
table persistée devrait être invalidée sur ces deux chemins, et la première invalidation manquée
produit exactement la divergence de chiffres que C4 veut interdire. Un type valeur recalculé n'a pas
ce mode de panne. Sur 30 jours, le calcul est de l'ordre de la milliseconde.

### 6.4 C5 — accepté, et planifié en dernier

Un module `Export/` : des `struct` `Codable` (DTO) **distinctes des `@Model`**, un `schema_version`
entier, un `ExportBuilder` qui parcourt la base, et un test de round-trip. Rendre les `@Model`
directement `Codable` coupleraient le format de sortie au schéma de persistance — deux choses qui
doivent pouvoir bouger séparément.

Contenu : les quatre entités de données + les `DailySummary` calculés + le profil + un **dictionnaire
de données** (métriques, unités, définitions des agrégats) embarqué dans le document. Chaque valeur
porte son unité et son fuseau ; un jour sans donnée est `null` avec une raison, jamais `0`.

Sortie v1 : un fichier via la feuille de partage système. L'utilisateur peut l'y déposer dans iCloud
Drive — ce qui suffit à la v1.5 de LIV-4 sans une ligne d'iOS en plus, et **sans contredire D2** (la
feuille de partage n'est pas CloudKit).

**Point de planning à dire franchement :** C5 est le seul item du lot avec un coût en jours, et c'est
aussi le seul sans aucune valeur pour la démo — rien dans les trois écrans ne l'utilise. Je le place
donc en **semaine 4, après que les trois écrans tournent sur l'appareil**. Si la semaine 4 est
grignotée, c'est C5 qui glisse, et rien dans C1–C4 n'en dépend. Dit autrement : les quatre
contraintes irréversibles sont tenues quoi qu'il arrive ; la seule qui coûte est aussi la seule
rattrapable après la démo.

### 6.5 Ce qui ne bouge pas

1. **Les données de santé sont un cache, pas un original (D7).** Le relais ne migrera jamais un
   miroir : il le reconstruit. La seule donnée à faire voyager, c'est `Meal`.
2. **Les unités sont canoniques (D10)** — secondes, kg, m, kcal, g. Pas « ce que la locale
   affichait ».
3. **Le calcul vit dans des types purs** (`SleepAggregator`, `WorkoutDeduplicator`,
   `TrendsCalculator`), sans SwiftUI ni HealthKit. Les questions du §4 de LIV-4 sont déjà ce que ces
   types calculent pour l'écran Tendances : un seul endroit à réutiliser, donc des chiffres
   identiques des deux côtés par construction et non par discipline.

---

## 7. Structure du code

Un projet Xcode, une cible app, aucune dépendance (D13).

```
Livaside/
  LivasideApp.swift              // ModelContainer, point d'entrée
  Models/                        // les 6 entités SwiftData + enums
  Health/
    HealthKitTypes.swift         // la liste des 8 types, en un seul endroit
    HealthAuthorization.swift    // demande + état, jamais de "refusé" affirmé
    HealthImporter.swift         // requêtes ancrées, ancres, suppressions
    SleepAggregator.swift        // §5.1, pur et testable
    WorkoutDeduplicator.swift    // §5.2, pur et testable
  Features/
    Today/
    MealEntry/
    Trends/
  Export/
    ExportDTO.swift              // structs Codable + schema_version (C5, D18)
    ExportBuilder.swift          // base -> document JSON
    DataDictionary.swift         // métriques, unités, définitions des agrégats
  Shared/
    TrendsCalculator.swift       // pur — produit les DailySummary (D9)
    DailySummary.swift           // struct, pas @Model
    Formatters.swift
    DayKey.swift                 // la seule façon de calculer un dayKey
    EventTimeZone.swift          // la seule façon de résoudre un timeZoneID (§4, D17)
  DebugData/                     // #if DEBUG, jeu de démo (D15)
```

`SleepAggregator`, `WorkoutDeduplicator` et `TrendsCalculator` sont des types purs : ils prennent des
valeurs, ils rendent des valeurs. Avec le **round-trip du sérialiseur** (C5), ce sont les quatre
seules choses à tester automatiquement — le reste se vérifie sur l'appareil.

---

## 8. Hors périmètre (à ressortir quand le scope dérive)

**Produit**
- Service MCP (architecture seulement, LIV-4), backend, API, comptes, synchro multi-appareils.
- Publication App Store, TestFlight, distribution.
- Base alimentaire, scan de code-barres, photo de repas, portions, recettes, suivi de l'eau.
- Objectifs, scores, badges, séries, notifications, rappels, coaching, conseils.
- Widgets, complications Apple Watch, raccourcis Siri, App Intents, Live Activities.
- ~~Export de données en v1~~ → **révisé (LIV-9, C5/D18)** : le *sérialiseur* JSON versionné est au
  périmètre v1, en semaine 4 (§6.4). Ce qui reste dehors : la ré-importation d'un export, le
  chiffrement du fichier, le dépôt automatique dans iCloud Drive.
- Mode sombre dédié (on suit le système), iPad, Mac, autres langues que le français.

**Technique**
- Écriture dans Apple Santé, livraison en arrière-plan, CloudKit, chiffrement applicatif
  supplémentaire, verrouillage biométrique de l'app.
- Siestes, phases de sommeil en graphique détaillé, fusion de plusieurs sources de sommeil dans une
  même nuit.
- Distances, pas, fréquence cardiaque, VFC, VO₂ max, zones cardiaques, **charge d'entraînement**
  (sans intensité relative, elle n'est pas calculable — arbitrage ouvert, §6.3).
- Périodes personnalisées et corrélations dans les tendances.

---

## 9. Points de coordination ouverts (aucun ne bloque le développement)

| Vers | Point | Hypothèse retenue en attendant |
|---|---|---|
| Privacy & Compliance (LIV-5) | Niveau de protection du fichier SwiftData | Protection par défaut d'iOS (`CompleteUntilFirstUserAuthentication`). Passer à `Complete` est faisable sans coût ici, précisément parce qu'il n'y a aucun travail en arrière-plan (D6) — à confirmer. |
| Privacy & Compliance (LIV-5) | Texte de `NSHealthShareUsageDescription` et de l'écran d'accueil | Texte provisoire écrit par moi, à remplacer par le leur sans changement de code. |
| Backend & MCP (LIV-4) | ~~Validation des 4 garanties du §6~~ → **traité (LIV-9)** : C1–C5 acceptées, 3 amendements, §6 | Reste à acter de leur côté : le contrat de synchro du §6.1 (miroirs en snapshot, `Meal` en différentiel) et la définition du sommeil par **union** et non par somme (§6.3). |
| Privacy & Compliance (LIV-5) | Le fichier d'export JSON (C5/D18) est en clair | Feuille de partage système, pas de chiffrement applicatif. Si leur cadrage exige autre chose, c'est à dire avant la semaine 4 — ça ne change pas le sérialiseur, seulement sa sortie. |
| CEO | Charge d'entraînement : `active_minutes` documenté comme tel, ou on ajoute FC/VFC (§6.3) | Option 1 — `training_load: null`, volume en minutes actives. Coût nul, pas de périmètre élargi. |
| Product Designer (LIV-7) | Les trois états d'affichage du §5.4 | Chaque carte et chaque graphique a besoin des trois. C'est la contrainte la plus structurante pour les maquettes. |
| CEO | FC de repos / VFC pour un indicateur de récupération (§4) | Dehors. Arbitrage de périmètre, pas une décision technique. |
