# Idée 5 — Repère de préparation qui tient compte de la musculation

**Statut :** proposée · **Date :** 4 octobre 2026 · **Veille :** [../veille-2026-10.md](../veille-2026-10.md)

## 1. Problème
- **Pour qui :** celui qui fait de la force autant que du cardio et reçoit un score de « récupération » calibré pour le cardio.
- **Preuve :** Athlytic est jugé biaisé vers le cardio : récupération complète affichée alors que l'effort musculaire intense ne l'est pas ([revue d'un testeur](https://ibikerun.substack.com/p/athlytic-app-review-iosapple-watch)), un seul avis. Apple va générer ses propres résumés sommeil/VO2 max ([MacRumors](https://macrumors.com/guide/ios-27-health-app-new-features)) : le terrain du score générique se réduit.

## 2. Hypothèse
Si nous affichons un repère « préparation » (baseline personnelle 60 jours : VFC, FC au repos, sommeil) corrigé par le volume de séances de force des 3 derniers jours, alors il est jugé plus juste que le repère générique, mesuré par : sur 4 semaines, ≥ 4 bêta-testeurs sur 5 jugent le repère « cohérent avec mon ressenti » ≥ 70 % des jours.

## 3. Lien avec les principes
- **Données passives d'abord :** VFC, FC, sommeil déjà dans Apple Health.
- **Vue unifiée :** croise sommeil et séances, un atout vis-à-vis des apps mono-domaine.
- **Temps gagné :** une valeur, un coup d'œil.
- Ouverture : l'IA de l'utilisateur peut déjà lire les mêmes données via `get_readiness_context`.

## 4. Impact / effort / confiance
- **Impact :** fort pour les sportifs, nul sinon · **Effort : L** (modèle, calibrage, validation sur 4 semaines) · **Confiance :** faible : peu de preuves, un seul avis, et notre `training_load` est `null` tant que la FC n'est pas lue ([architecture](../../architecture-mcp.md)).
- Réversibilité mauvaise : un score affiché crée une attente.

## 5. Risques données et privacy
Lecture de la VFC et de la FC : **nouveaux types HealthKit sensibles**, donc nouvelle autorisation et mise à jour de la politique. Privacy & Compliance doit relire avant tout prototype sur données réelles. Risque d'être perçu comme un avis médical ; ton DA obligatoire (pas de rouge, pas de jugement).

## 6. Recommandation
**No-go pour l'instant.** Effort L, confiance faible, nouvelles données sensibles, et hors périmètre MVP. À reconsidérer après la bêta, si les sportifs le demandent.
