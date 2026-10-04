<!-- Source : Paperclip LIV-7, document `design` -->

# Design & Maquettes — MVP Livaside

Ce document définit les maquettes, le système de design et les règles des graphiques pour le MVP de Livaside (LIV-7). L'objectif est de fournir à l'iOS Engineer toutes les clés pour implémenter l'interface sans question ouverte, en respectant le positionnement *live aside* (la santé à vos côtés, pas devant vous).

## 1. Principes & Système de Design

Le mot d'ordre est **retenue**. L'interface ne doit pas crier pour attirer l'attention. Elle utilise les standards d'iOS (Human Interface Guidelines) pour sembler instantanément familière et native.

### Couleurs (Sémantiques iOS natives)
- **Fonds** : `SystemGroupedBackground` (Gris très clair) pour le fond de l'app, `SecondarySystemGroupedBackground` (Blanc) pour les cartes.
- **Textes** : `Label` pour la donnée principale, `SecondaryLabel` pour le contexte et les axes des graphiques.
- **Accents (pour les icônes et les graphiques)** :
  - Sommeil : `SystemIndigo`
  - Sport / Volume : `SystemOrange`
  - Nutrition / Repas : `SystemGreen`
  - Poids : `SystemBlue`

### Typographie (San Francisco)
- **Grands Titres (écrans)** : `Large Title`, Bold.
- **Chiffres clés** : `Title 1` ou `Large Title`, variante **Rounded** pour un aspect légèrement plus chaleureux.
- **Titres de cartes** : `Headline`, Semibold.
- **Axes / Labels** : `Caption 1` ou `Footnote`, `SecondaryLabel`.

### Les 3 états d'affichage (Gestion des trous de données)
Chaque carte et graphique doit gérer ces trois états de manière élégante :
1. **Donnée présente** : Affichage normal de la valeur et du graphique.
2. **Pas de valeur (trou de donnée)** : Affichage d'un tiret cadratin discret « — » à la place du chiffre. Le graphique affiche un espace vide pour ce jour. Pas de zéros artificiels.
3. **Pas l'autorisation (HealthKit)** : Icône de cadenas discret + bouton texte « Autoriser » qui déclenche la demande HealthKit ou renvoie vers les Réglages.

---

## 2. Les 3 Écrans de la Démo

### Écran 1 : Aujourd'hui (`TodayView`)
**Objectif :** Une vue d'ensemble instantanée de la journée. Densité modérée, hiérarchie claire.
- **Structure** : `ScrollView` verticale. Titre de navigation « Aujourd'hui ».
- **Composant Carte** : Bords arrondis (16pt), padding interne généreux (16pt), icône + Titre en haut à gauche, Valeur principale en grand au centre/bas.
- **Ordre des cartes** :
  1. **Sommeil** : Icône lune (`SystemIndigo`). Valeur en heures et minutes (ex: 7h 24m).
  2. **Nutrition** : Icône pomme ou couvert (`SystemGreen`). Valeur en Calories (ex: 1850 kcal). Bouton d'action « + » bien visible dans le coin supérieur droit de la carte pour ajouter un repas.
  3. **Entraînement** : Icône flamme ou chrono (`SystemOrange`). Valeur en minutes actives.
  4. **Poids** : Icône balance (`SystemBlue`). Valeur avec unité (ex: 72.4 kg).

### Écran 2 : Ajouter un repas (`MealEntryView`)
**Objectif :** Saisie sous les 15 secondes. Friction zéro.
- **Format** : Modale (`.sheet`), format demi-écran (detents: `.medium`) si possible, sinon modale standard.
- **Focus immédiat** : Le clavier numérique s'ouvre automatiquement (focus sur le champ Calories).
- **Contenu** :
  - Titre : « Ajouter un repas »
  - Champ de saisie **Calories** : Énorme, centré, clavier `.numberPad`. Placeholder « 0 kcal ».
  - Puces de sélection (Chips) pour le type : [Matin] [Midi] [Soir] [Snack]. (Pré-sélectionné selon l'heure du jour).
- **Validation** : Bouton principal large en bas « Enregistrer » (couleur `SystemGreen`). Appuyer sur "Terminé" sur le clavier valide également.

### Écran 3 : Tendances (`TrendsView`)
**Objectif :** Comprendre sa direction d'un seul coup d'œil, sans analyse complexe.
- **Structure** : `Picker` (Segmented Control) en haut de l'écran : « 7 Jours » | « 30 Jours ».
- **Défilement** : Vertical, empilant les graphiques.
- **Cartes de graphiques** : Chaque carte contient :
  - L'en-tête (Icône + Titre).
  - La moyenne sur la période affichée en grand (ex: « Moy. 7h 10m »).
  - Le graphique (Swift Charts).

---

## 3. Règles Visuelles des Graphiques (Swift Charts)

La clarté prime sur la densité de données. On supprime le bruit (quadrillages lourds, axes redondants).

### A. Graphique Sommeil (BarChart)
- **Axe X** : Jours de la semaine (L, M, M, J, V, S, D) ou dates.
- **Axe Y** : Heures (0h, 4h, 8h, 12h). Lignes de grille horizontales très discrètes.
- **Représentation** : Barres verticales (`SystemIndigo`).
- **Ligne de référence** : Ligne pointillée (`RuleMark`) à 8h pour situer son objectif implicitement.
- **Trous** : Jour sans donnée = absence de barre (espace vide).

### B. Graphique Volume d'entraînement (BarChart)
- **Axe X** : Jours.
- **Axe Y** : Minutes actives.
- **Représentation** : Barres verticales (`SystemOrange`).
- **Trous** : Jour sans donnée = absence de barre.

### C. Graphique Poids (LineChart avec points)
- **Axe X** : Jours.
- **Axe Y** : Kg. **Important :** L'axe Y ne démarre **pas** à zéro. Il doit être dynamique, calibré sur `(min - 2kg)` et `(max + 2kg)` de la période affichée, pour rendre les variations visibles.
- **Représentation** : Ligne continue (`SystemBlue`) + Points (`Symbol`) sur chaque donnée réelle.
- **Trous** : Si un jour manque, la ligne connecte le point précédent au point suivant de manière fluide (`InterpolationMethod.catmullRom` ou ligne droite). Les points marquent explicitement les jours où une pesée a eu lieu. S'il y a un trou de plus de 5 jours, la ligne s'interrompt pour éviter de fausses continuités.

## 4. Livrables & Implémentation
Ce document fait office de maquette fonctionnelle. L'iOS Engineer peut utiliser les composants standard de SwiftUI et Swift Charts en suivant ces spécifications. Aucun asset image n'est requis (SF Symbols uniquement). Les marges et padding doivent respecter les espacements multiples de 8 (8, 16, 24, 32) propres aux HIG.
