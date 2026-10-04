# Idée 4 — Bilan hebdomadaire croisé sommeil · séances · repas

**Statut :** proposée · **Date :** 4 octobre 2026 · **Veille :** [../veille-2026-10.md](../veille-2026-10.md)

## 1. Problème
- **Pour qui :** l'utilisateur qui veut comprendre ses semaines sans comparer trois apps.
- **Preuve :** les apps sont mono-domaine (récupération chez Athlytic/Bevel, nutrition chez Yazio/MyFitnessPal, voir la veille). Apple ajoute des résumés IA sur ses seules données ([MacRumors](https://macrumors.com/guide/ios-27-health-app-new-features)), sans nutrition tierce. Aucune preuve directe d'attente : hypothèse.

## 2. Hypothèse
Si nous affichons une carte hebdomadaire de trois constats chiffrés qui croisent les domaines (« les 2 nuits < 6 h ont suivi les 2 jours de séance tardive »), alors l'utilisateur trouve la vue unifiée utile, mesuré par : ≥ 3 bêta-testeurs sur 5 jugent au moins un constat sur trois « nouveau et vrai » ; les constats sont calculés en moins de 2 s, localement.

## 3. Lien avec les principes
- **Vue unifiée :** cœur de la promesse.
- **Données passives d'abord :** si le repas est loggé, sinon on s'en tient au sommeil et aux séances.
- **Temps gagné :** une lecture de 20 s remplace trois écrans de tendances.
- **MCP :** même base que `get_trends`, exploitable par l'IA.

## 4. Impact / effort / confiance
- **Impact :** fort si les constats sont justes · **Effort : M à L** (règles de corrélation simples, choix statistiques prudents, design) · **Confiance :** faible à moyenne : sur 7 jours, une corrélation est souvent du bruit.
- Kano : fonction qui enchante, ou qui énerve si fausse.

## 5. Risques données et privacy
Calcul local, pas de nouvelle donnée. Risque principal : fausse causalité présentée comme un fait. Formuler « a coïncidé avec », jamais « a causé ». Relecture Privacy si le texte s'approche d'un conseil de santé.

## 6. Recommandation
**À creuser.** Avant de prototyper : voir si les données de la bêta (4 semaines, 5 testeurs) montrent assez de régularité pour des constats fiables. Prototype possible ensuite sur 3 règles seulement.
