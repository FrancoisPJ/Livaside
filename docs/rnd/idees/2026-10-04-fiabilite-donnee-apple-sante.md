# Idée 2 — Indicateur de fiabilité des données Apple Health

**Statut :** proposée · **Date :** 4 octobre 2026 · **Veille :** [../veille-2026-10.md](../veille-2026-10.md)

## 1. Problème
- **Pour qui :** celui qui dort sans sa montre, la charge mal ou change de montre, et lit un sommeil ou un score faux sans le savoir.
- **Preuve :** la « readiness » de Bevel dérive quand Apple Health est incomplet ou mal horodaté ([Yahoo Tech](https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html)) ; Athlytic dépend d'une mesure nocturne fiable ([revue](https://ibikerun.substack.com/p/athlytic-app-review-iosapple-watch)). Aucune de ces apps ne dit « cette donnée est douteuse » dans sa promesse.

## 2. Hypothèse
Si nous affichons « nuit incomplète / pas de mesure / durée atypique » à côté des chiffres, au lieu de les présenter comme sûrs, alors l'utilisateur fait davantage confiance aux autres chiffres, mesuré par : le détecteur signale correctement ≥ 90 % de 20 cas de test (nuits tronquées, trous, doublons de sources) sur données de démo, avec moins de 5 % de faux signalements sur les nuits normales.

## 3. Lien avec les principes
- **Données passives d'abord :** on exploite ce qu'Apple Health fournit déjà, sans saisie.
- **Temps gagné :** évite de chercher pourquoi un chiffre semble faux.
- **Ouverture / MCP :** le champ de qualité part aussi dans les réponses MCP (`get_sleep`), pour que l'IA ne conclue pas sur une nuit tronquée. Avantage MCP net.
- Données à l'utilisateur : neutre.

## 4. Impact / effort / confiance
- **Impact :** moyen à fort sur la confiance · **Effort : M** (règles sur durée, sources, trous ; messages à écrire avec le Product Designer) · **Confiance :** moyenne (le seuil de « atypique » reste à calibrer).
- Kano : attente de base cachée, rarement exprimée mais décisive quand elle manque.

## 5. Risques données et privacy
Aucune nouvelle donnée collectée, calcul local. Risque de ton : un message qui sonne médical (« anomalie ») est à bannir. Libellé factuel (« 3 h 10 mesurées »), à valider avec Privacy & DA.

## 6. Recommandation
**Go prototype.** Brief : détecteur à règles sur la nuit, 20 cas de test, critère ci-dessus.
