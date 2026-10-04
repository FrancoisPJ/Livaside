# Idée 1 — Export complet des données en un geste

**Statut :** proposée · **Date :** 4 octobre 2026 · **Veille :** [../veille-2026-10.md](../veille-2026-10.md)

## 1. Problème
- **Pour qui :** l'utilisateur qui veut garder la main sur ses données (ou changer d'app) ; le bêta-testeur qui veut vérifier ce qu'on stocke.
- **Preuve :** chez MyFitnessPal l'export est payant, avec le scan et les macros, et le paywall est la plainte la plus citée ([Unstar](https://unstar.app/blog/is-myfitnesspal-premium-worth-it-paywall-app-reviews-2026)). Aucune preuve directe côté Livaside : hypothèse à tester en bêta.

## 2. Hypothèse
Si nous offrons un export gratuit en un tap (CSV par domaine + un JSON complet), alors la confiance dans « vos données vous appartiennent » progresse, mesuré par : 100 % des bêta-testeurs qui testent l'export obtiennent un fichier lisible en moins de 30 s, et au moins 3 sur 5 citent l'export comme une raison de confiance dans le questionnaire de bêta.

## 3. Lien avec les principes
- **Données à l'utilisateur :** c'est le principe en acte.
- **Temps gagné :** un tap, pas de formulaire de demande.
- **Ouverture :** formats standards, réutilisables dans un tableur ou une IA.
- Vue unifiée : neutre.

## 4. Impact / effort / confiance
- **Impact :** moyen (confiance et argument de landing) · **Effort : S** (données déjà locales, feuille de partage iOS) · **Confiance :** élevée sur la faisabilité, moyenne sur l'effet.
- L'architecture MCP prévoit déjà une sortie par la feuille de partage (v1.5), donc peu de travail nouveau.

## 5. Risques données et privacy
Le fichier exporté contient des données de santé en clair : il quitte la protection de l'app. À faire relire par Privacy & Compliance : avertissement avant partage, aucun envoi automatique, pas de copie conservée par l'app, cohérence avec la règle Apple 5.1.3 (pas d'écriture iCloud par l'app).

## 6. Recommandation
**Go prototype** (petit, réversible). Brief : export CSV + JSON sur données de démo, relu par Privacy avant tout test sur données réelles.
