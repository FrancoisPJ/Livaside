# Qualité — état des lieux et registre de dette technique

*Quality & Performance Engineer · audit initial (LIV-28) · 4 octobre 2026*

**Périmètre.** `HealthKitSpike/` (synchro HealthKit, agrégats, stockage SwiftData) et le serveur MCP.
**Il n'y a pas de code serveur MCP dans le dépôt** : l'audit porte sur `docs/architecture-mcp.md`
(et `docs/amendement-liv4.md`). Méthode : lecture de code, tests exécutés avec `swift test`
(`HealthKitSpike/QATests`). Aucun test sur appareil réel : ce qui dépend d'HealthKit en conditions
réelles est marqué « à confirmer ».

## Ce qui est solide (à ne pas casser)

- Idempotence de la synchro : requête ancrée par type, `HealthRecord.uuid` unique, ajouts filtrés par
  UUID déjà connu, suppressions propagées. Rejouer une synchro ne duplique pas (lecture de
  `HealthKitSync.importChanges`).
- Sommeil : union des intervalles entre sources (testé : montre + app sur la même nuit = 8 h, pas 15 h),
  nuit attribuée au jour du réveil.
- Absence ≠ zéro : un jour sans donnée garde des `nil`.
- Dégradation gracieuse : base verrouillée en arrière-plan ignorée, erreurs mémorisées dans `SyncState`.

## Registre, trié par sévérité

| Id | Sév. | Constat | Statut |
|---|---|---|---|
| QUAL-01 | **Majeur** | Magasin illisible : les repas (donnée non reconstructible) sont mis de côté sans reprise | **Corrigé** (LIV-29) |
| QUAL-02 | **Majeur** | Architecture MCP : un instantané complet vide ou périmé écrase une bonne projection du relais | Contrat amendé (LIV-30, G1–G3), soumis au CEO |
| QUAL-03 | **Majeur** | Clés de jour figées au fuseau du lancement de l'app | **Corrigé** (branche `qa/cle-jour-fuseau-horaire`) |
| QUAL-04 | Mineur | Fenêtre de 90 jours : échantillons anciens arrivés tard jamais importés | Ouvert |
| QUAL-05 | Mineur | Permission refusée indiscernable de « aucune donnée » | À signaler au Head of R&D / Product Designer |
| QUAL-06 | Mineur | Aucun test dans le target app, aucune CI de tests | Amorcé (paquet `QATests`) |
| QUAL-07 | Mineur | `DailyHealthSnapshot.dayKey` sans contrainte d'unicité | Ouvert |

### QUAL-01 — Magasin illisible : repas non récupérables (majeur)

- **Preuve.** `Models.swift`, `LivasideStore.openLocalContainer()` : si `ModelContainer` échoue, les
  fichiers `.store`, `-shm`, `-wal` sont renommés (`try?`, erreurs ignorées) et l'app repart d'un
  magasin vide. Le commentaire du code l'admet : « seuls les repas restent dans la copie mise de côté ».
  De plus, si le renommage échoue en silence, la seconde ouverture échoue aussi et l'app tombe sur
  `fatalError` à chaque lancement.
- **Impact.** Après une migration ratée, l'utilisateur voit tous ses repas disparaître. Santé se
  réimporte, pas les repas. C'est une perte de données perçue, le défaut le plus grave pour une app santé.
- **Correctif proposé.** (1) Ouvrir la copie mise de côté en lecture et réimporter les `Meal`/`FoodEntry`
  dans le magasin neuf ; (2) ne pas faire de `fatalError` : repli en mémoire avec bandeau d'alerte ;
  (3) test de migration sur un magasin d'une version précédente. Demi-journée à une journée : sous-ticket
  pour l'iOS Engineer.
- **Correctif (LIV-29).** `StoreRecovery.swift` : les fichiers du magasin illisible sont déplacés
  ensemble, sous leurs noms d'origine, dans `Livaside-illisible-<horodatage>/` (le `-wal`, qui contient
  les derniers repas, reste ainsi lisible ; tout ou rien, pour qu'aucun `-wal` orphelin ne soit rejoué sur
  le magasin neuf). Les `Meal` sont relus en SQLite sur une copie temporaire, indépendamment du schéma,
  et réimportés avec leurs identifiants. Si le magasin ne peut être ni déplacé ni recréé : repli en
  mémoire avec les repas relus, plus de `fatalError`. Une alerte prévient l'utilisateur dans les deux cas.
  Tests `StoreRecoveryTests` (paquet `QATests`) sur un magasin d'une version précédente dont la migration
  échoue réellement (`calories` texte puis entier). **Limite** : seuls les `Meal` sont relus ; les lignes
  du journal `FoodEntry` (LIV-22) ne le sont pas encore, à ajouter quand leur schéma sera figé.

### QUAL-02 — Instantané complet : écrasement par du vide ou du périmé (majeur, conception)

- **Preuve.** `docs/architecture-mcp.md` §2 : « chaque push remplace intégralement la projection du
  relais », sans garde-fou. Or l'app peut produire un export vide ou réduit sans que rien ne soit
  anormal côté app : accès Santé révoqué (miroir qui se vide par suppressions), magasin neuf après
  QUAL-01, fenêtre de 90 jours. Deux pushs concurrents ou rejoués dans le désordre (réseau lent) :
  le plus ancien peut gagner.
- **Impact.** Les réponses de l'IA de l'utilisateur deviennent fausses ou vides sans erreur visible.
  Le relais étant « jetable », pas de perte définitive, mais une donnée fausse servie à l'assistant.
- **Correctif proposé.** Numéro de séquence ou horodatage de génération monotone par appareil
  (le relais refuse un push plus ancien) ; refus ou confirmation d'un instantané très inférieur au
  précédent (par ex. moins de 50 % des enregistrements) ; champ `generatedAt` exposé par les outils MCP
  pour que l'assistant sache de quand date la donnée. À intégrer au contrat avant d'écrire le service.
  Sous-ticket pour le Backend & MCP Engineer.

### QUAL-03 — Clés de jour figées au fuseau du lancement (majeur, corrigé)

- **Preuve.** `LivasideDate.keyFormatter` était un `static let` : son `timeZone` est copié une fois au
  premier usage, alors que `calendar` est `autoupdatingCurrent`. Le test
  `testKeyFollowsTimeZoneChangeAfterFirstUse` échouait avant correctif : un instant à 01:30 le 11 mars
  à Auckland était rangé au 10 mars (fuseau Paris du lancement). `startOfDay` suivait le nouveau
  fuseau pendant que `key(for:)` gardait l'ancien : les deux ne parlaient plus du même jour.
- **Impact.** Après un voyage (app restée en mémoire, ou réveillée en arrière-plan), sommeil, séances
  et poids se retrouvent attribués au mauvais jour, et `rebuildSnapshots` crée des clés
  incohérentes avec les jours qu'il itère. Aucune perte, mais des graphiques faux.
- **Correctif.** `key(for:)` calcule depuis `calendar.dateComponents` à chaque appel. Tests : changement
  de fuseau, journées de 23 h et 25 h (passages à l'heure d'été et d'hiver 2026).

### QUAL-04 — Fenêtre de 90 jours (mineur, à confirmer sur appareil)

- **Preuve.** `HealthKitSync.importChanges` : prédicat `start >= now - 90 j` appliqué à la requête
  ancrée. Un échantillon ajouté plus tard à Santé avec une date de début plus ancienne (import de
  l'historique d'une app tierce, synchronisation tardive d'un appareil) est exclu et l'ancre avance.
- **Impact.** Poids ou séances anciens jamais visibles ; sans effet sur les tendances 30 jours.
  Pertinent pour l'export MCP si l'on promet « tout l'historique ».
- **Correctif proposé.** Décider avec le Head of R&D de la profondeur d'historique voulue ; si besoin,
  premier import sans prédicat de date pour le poids et les séances (volumes faibles).

### QUAL-05 — Permission refusée = « aucune donnée » (mineur, UX)

- **Preuve.** Commentaire de `synchronize()` : HealthKit ne dit pas si la lecture est refusée ; un
  résultat vide est présenté comme « aucune donnée ou accès à vérifier ». **Passe la main** au Head of
  R&D / Product Designer : texte et écran d'aide, pas un bug de code.

### QUAL-06 — Pas de tests dans le projet (mineur, dette)

- **Preuve.** Aucun target de test dans `LivasideSpike.xcodeproj` ; pas de CI de tests.
- **Action faite.** Paquet `HealthKitSpike/QATests` : `cd HealthKitSpike/QATests && swift test`
  (5 tests, < 1 s, sans simulateur). Les sources sont des liens symboliques vers `LivasideSpike/`.
  Limite : si `Models.swift` référence d'autres fichiers (nutrition, CIQUAL…), il faut ajouter les
  liens correspondants dans `Sources/QACore/`. **Proposition** : migrer vers un vrai target de test Xcode
  quand le projet se stabilise, puis brancher la CI (décision CEO / iOS Engineer).

### QUAL-07 — `dayKey` non unique (mineur)

- **Preuve.** `DailyHealthSnapshot.dayKey` n'a pas `@Attribute(.unique)`. Aujourd'hui une seule
  écriture (`rebuildSnapshots`, sur le thread principal) : pas de doublon constaté. Risque si une
  seconde voie d'écriture apparaît (démo, import, extension). Correctif : `.unique` + migration légère.

## À mesurer ensuite (pas de chiffre à ce jour)

- Temps du premier import 90 jours et de `rebuildSnapshots` : tout est sur `@MainActor`
  (`HealthKitSync`), donc à chronométrer avec Instruments sur un jeu de données volumineux avant
  toute optimisation. Aucune mesure n'a été faite : pas de constat de performance à ce stade.
- Batterie : `enableBackgroundDelivery(.immediate)` sur 4 types, une synchro complète à chaque
  réveil. À mesurer avant de changer quoi que ce soit.
