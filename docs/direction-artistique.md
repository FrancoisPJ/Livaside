# Direction artistique — Livaside (proposition v1)

**Statut :** proposition du CEO, à valider par le fondateur. Elle complète `design-maquettes.md` (LIV-7), qui fixe les écrans et les graphiques, et ne change aucun parcours.

## 1. Le constat

La démo et la landing utilisent aujourd'hui les couleurs système d'iOS : fond gris `#F2F2F7`, accent vert `#34C759`, indigo, orange et bleu système. C'est propre, mais on dirait l'app Santé d'Apple. Rien ne dit « Livaside » sur une capture App Store.

## 2. L'idée : « à côté »

*Live aside*, c'est la santé à vos côtés, pas devant vous. La DA doit avoir l'air **calme, chaleureuse et en retrait**. On pense à un carnet posé à côté de vous plutôt qu'à un tableau de bord de sport.

Trois mots : **posé, chaleureux, net.**

| On veut | On évite |
|---|---|
| Fonds chauds, papier, lin | Noir néon des apps de fitness |
| Couleurs désaturées, naturelles | Rouge alarme, vert « bravo », dégradés |
| Chiffres lisibles, en grand | Badges, séries, confettis, culpabilisation |
| Du vide, de l'air | Écrans denses, jauges partout |

## 3. Palette

Toutes les valeurs ont été vérifiées en contraste WCAG (ratios ci-dessous calculés sur le fond de l'app).

### Neutres

| Jeton | Clair | Sombre | Usage |
|---|---|---|---|
| `bg` (Lin) | `#F6F3EE` | `#141413` | Fond de l'app et de la landing |
| `surface` | `#FFFFFF` | `#1F1E1C` | Cartes |
| `ink` | `#1C1B19` (15,6:1) | `#F3F0EA` (16,2:1) | Chiffres, titres |
| `ink-soft` | `#6B675F` (5,1:1) | `#A8A39A` (7,4:1) | Contexte, axes, légendes |
| `line` | `#E4DFD6` | `#2E2C29` | Séparateurs, grille des graphiques |

### Marque

| Jeton | Clair | Sombre | Usage |
|---|---|---|---|
| `sauge` | `#3F6B4E` (5,5:1) | `#8FBF9C` (8,9:1) | Boutons principaux, liens, icône d'app. Texte blanc sur sauge : 6,1:1 |

### Domaines (graphiques et icônes)

| Domaine | Clair | Sombre | Remplace |
|---|---|---|---|
| Sommeil — *Nuit* | `#5A5FC4` (4,9:1) | `#9A9DF2` | SystemIndigo |
| Sport — *Terracotta* | `#C8643C` (3,6:1) | `#EE9A74` | SystemOrange |
| Nutrition — *Feuille* | `#4E8F5F` (3,5:1) | `#86C496` | SystemGreen |
| Poids — *Ardoise* | `#3A74A8` (4,5:1) | `#82B3DE` | SystemBlue |

**Règle :** les couleurs de domaine servent aux barres, aux lignes et aux icônes. Elles passent toutes le seuil de 3:1 exigé pour les éléments graphiques. Sport et Nutrition sont sous 4,5:1 en clair, donc **jamais pour du petit texte**. Le texte reste en `ink` / `ink-soft`.

Pas de rouge dans l'app. Une baisse de sommeil ou une prise de poids n'est pas une erreur.

## 4. Typographie

Que des polices Apple, gratuites et déjà présentes sur l'appareil. Aucune police à charger, donc aucune requête réseau (contrainte privacy LIV-5).

| Rôle | iOS | Landing (CSS) |
|---|---|---|
| Titres d'écran, titres de la landing | **New York** (`.serif`), Semibold | `ui-serif, "New York", "Iowan Old Style", Georgia, serif` |
| Chiffres clés | **SF Pro Rounded**, Semibold, chiffres tabulaires | `ui-rounded, "SF Pro Rounded", system-ui` |
| Texte, labels, axes | SF Pro, styles dynamiques | `system-ui, -apple-system` |

Le serif des titres apporte le côté carnet. C'est la signature la plus visible pour un coût nul. Les chiffres restent en Rounded, comme le prévoyait déjà LIV-7.

## 5. Logo et icône

- **Logotype :** `livaside` en minuscules, New York Medium, interlettrage légèrement resserré.
- **Symbole :** deux cercles côte à côte. Un grand (la vie) et un petit posé à sa droite (la santé, à côté). C'est le nom traduit en image, et il reste lisible à 16 px.
- **Icône d'app :** fond `sauge`, symbole en `#F6F3EE`. Variante sombre et variante teintée iOS 18 à prévoir.
- À livrer en SVG (logo, symbole) et en catalogue d'assets Xcode (icône 1024 px et variantes).

## 6. Formes, espace, mouvement

- Cartes arrondies à **20 pt** (16 pt aujourd'hui), sans ombre portée. Seule la différence `bg` / `surface` les détache.
- Espacements multiples de 8, comme dans LIV-7.
- Graphiques : barres arrondies en haut, grille en `line`, ligne d'objectif sommeil en pointillé `ink-soft`.
- Icônes : SF Symbols, graisse Regular, monochromes dans la couleur du domaine.
- Mouvement : animations système uniquement (`.smooth`). Pas de rebond, pas de célébration.

## 7. Ton

On vouvoie, on écrit court, on reste factuel : « 7 h 24 de sommeil », pas « Super nuit ! ». On ne juge pas les chiffres, on les montre. C'est le même ton que la landing validée (LIV-10).

## 8. Ce que ça change concrètement

1. **App iOS** : un fichier `Theme.swift` (couleurs, polices, rayons) et un catalogue de couleurs clair/sombre. Les trois écrans les utilisent au lieu des couleurs système. Pas de nouveau parcours.
2. **Landing** : on remplace les variables CSS existantes (`--bg`, `--accent`, polices). La structure de la page ne bouge pas.
3. **Visuels** : on régénère les 6 visuels de landing et les 10 captures App Store une fois l'app mise à jour.
4. **Logo et icône** : on les crée, on les intègre à l'app et à la landing (favicon, en-tête).
