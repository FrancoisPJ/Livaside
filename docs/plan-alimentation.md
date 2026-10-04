# Plan : onglet Alimentation

**Statut :** proposition du CEO, à valider par le fondateur.
**Demande (LIV-15, 4 octobre 2026) :** l'onglet « Ajouter » disparaît. Il est remplacé par un onglet **Alimentation** complet : aliments de base CIQUAL, scan de code-barres, et notes de plat transformées en aliment par une IA via MCP.

## 1. Ce que devient l'app

La barre d'onglets passe à **Aujourd'hui · Alimentation · Tendances**. La carte Nutrition d'Aujourd'hui ouvre directement l'onglet Alimentation.

L'onglet Alimentation contient :

| Bloc | Ce qu'il fait |
|---|---|
| **Journal du jour** | Repas du jour (Matin, Midi, Soir, Collation) avec leurs aliments, et un total calories, protéines, glucides, lipides et fibres. On change de jour d'un glissement. |
| **Ajouter un aliment** | Une seule barre de recherche, qui cherche à la fois dans CIQUAL, dans mes aliments et dans mes récents. On choisit la quantité en grammes ou en portion (« 1 yaourt », « 1 tranche »). Objectif : moins de 15 s pour un aliment connu. |
| **Scanner** | La caméra lit le code-barres et retrouve le produit (nom, valeurs pour 100 g, Nutri-Score), puis on choisit la quantité. Si le produit est inconnu, on le crée à la main à partir de l'étiquette, et il est gardé. |
| **Mes aliments et mes plats** | Aliments perso, et plats composés de plusieurs aliments (« mon porridge », « bolo maison »), avec leurs valeurs calculées. Favoris et récents. |
| **Notes de plat** | Note libre (« assiette de pâtes carbo au resto, grosse portion »), éventuellement avec une photo. Elle reste en **attente** jusqu'à ce que l'IA de l'utilisateur la transforme en aliment chiffré. L'utilisateur valide le résultat avant qu'il entre dans le journal. |
| **Repères** | Objectif calories et répartition des macros, facultatifs. On affiche l'écart, sans jugement ni rouge, comme le prévoit la DA. |
| **Raccourcis** | Copier le repas d'hier, ré-ajouter un plat en un geste. |

Les repas déjà saisis sont conservés : on les migre vers le nouveau modèle.

## 2. Les trois sources de données

### CIQUAL : embarqué, sans réseau
CIQUAL est la table de composition des aliments de l'ANSES : environ 3 200 aliments génériques, avec macros et micronutriments. Elle est publiée en données ouvertes sous Licence Ouverte Etalab, ce qui permet la réutilisation commerciale avec mention de la source. Privacy doit confirmer la version de la licence.

**Décision proposée :** on **embarque** la table dans l'app sous forme d'une base locale (quelques Mo), mise à jour à chaque version de l'app. Il n'y a aucune requête réseau, donc la contrainte LIV-5 « zéro réseau » tient.

### Code-barres : demande à arbitrer
Pour retrouver un produit à partir de son code, il faut une base produits. La référence en France est **Open Food Facts** : gratuite, sous licence ODbL (mention obligatoire et partage à l'identique de la base), mais on l'interroge **en ligne**.

C'est **la première requête réseau de l'app**, et elle casse la règle « zéro réseau » de LIV-5.

| Option | Pour | Contre |
|---|---|---|
| **A. Requête Open Food Facts à chaque scan** *(recommandée)* | Base complète et à jour, simple | Réseau : on n'envoie **que le code-barres**, sans identifiant ni donnée de santé. Privacy doit valider l'effet sur la fiche App Store et la politique de confidentialité. |
| B. Base Open Food Facts France embarquée | Zéro réseau | Plusieurs centaines de Mo, vite périmée, ODbL plus lourde à gérer |
| C. Pas de base : saisie de l'étiquette à chaque nouveau produit | Zéro réseau | Le scan perd presque tout son intérêt |

Une fois scanné, un produit est gardé en local : on ne le redemande plus jamais.

### Notes de plat → IA via MCP : changement d'architecture
LIV-4 a fixé un MCP **en lecture seule**, avec un relais qui **ne renvoie jamais rien au téléphone**. Or transformer une note en aliment demande deux choses que LIV-4 exclut :

1. un **outil d'écriture** côté MCP, par exemple `nutrition:propose`, qui serait la première portée d'écriture ;
2. un **chemin retour** du relais vers le téléphone.

Le principe reste « l'IA de votre choix, jamais imposée dans l'app ».

**Proposition :**
1. La note est envoyée au relais avec la projection.
2. Dans son assistant, l'utilisateur demande « chiffre mes notes de repas ».
3. L'assistant lit les notes en attente et propose un aliment chiffré via `nutrition:propose`.
4. Le téléphone récupère la proposition au prochain lancement et l'affiche dans une **boîte « À valider »**.
5. Rien n'entre dans le journal sans un geste de l'utilisateur.

Le service MCP n'existe pas encore : LIV-4 est une décision d'architecture, pas du code. **On découpe donc en deux temps :**
- **Maintenant :** les notes de plat existent dans l'app (saisie, photo, statut « en attente », chiffrage manuel possible). Le Backend & MCP Engineer amende LIV-4 avec ce flux d'écriture, sans coder.
- **Plus tard**, quand le service MCP sera construit : on branche le flux.

## 3. Modèle de données (à préciser par l'iOS Engineer)

- `Food` : aliment, avec sa source (`ciqual`, `openfoodfacts`, `perso`, `ia`), le code CIQUAL ou EAN, les valeurs pour 100 g et les portions nommées.
- `Recipe` : plat composé (`Food` × grammes), dont les valeurs sont calculées.
- `FoodEntry` : un aliment ou un plat, une quantité, un repas (Matin, Midi, Soir, Collation), une date. Les valeurs nutritionnelles sont **figées au moment de l'ajout**, pour qu'un historique ne bouge pas si la base change.
- `MealNote` : texte, photo facultative, statut (`en attente`, `proposée`, `validée`, `rejetée`), lien vers l'aliment créé.
- Migration de `Meal` vers `FoodEntry`. Mise à jour de la projection MCP de LIV-4 (`nutrition:read`).

## 4. L'équipe et l'ordre

| # | Tâche | Qui | Démarre |
|---|---|---|---|
| 1 | Maquettes de l'onglet Alimentation (journal, recherche, quantité, scan, plats, notes, « À valider »), dans la DA | Product Designer | Tout de suite |
| 2 | Modèle de données, import CIQUAL embarqué, recherche locale, migration des repas existants | iOS Engineer | Tout de suite |
| 3 | Avis privacy : licence CIQUAL, option code-barres (réseau Open Food Facts, ODbL), fiche App Store et politique de confidentialité, photos des notes, notes envoyées au relais | Privacy & Compliance | Tout de suite |
| 4 | Amendement LIV-4 : portée d'écriture `nutrition:propose`, chemin retour relais → téléphone, boîte « À valider ». Décision seulement, pas de code. | Backend & MCP Engineer | Tout de suite |
| 5 | Onglet Alimentation complet (journal, recherche, quantités, plats, favoris et récents, notes, repères), suppression de l'onglet Ajouter | iOS Engineer | Après 1 et 2 |
| 6 | Scan de code-barres et fiche produit | iOS Engineer | Après 3 et 5 |

**Fini quand** l'onglet Alimentation tourne sur iPhone :
- recherche CIQUAL hors ligne ;
- scan fonctionnel ;
- plats et notes en place ;
- repas existants migrés ;
- build vert ;
- captures jointes ;
- amendement MCP écrit, prêt à être construit avec le service.

## 5. Ce que je te demande de trancher

1. **Code-barres :** option A (Open Food Facts en ligne, seulement le code envoyé), sous réserve de l'avis Privacy ? C'est ma recommandation.
2. **Notes via IA :** OK pour les livrer en deux temps (notes dans l'app maintenant, branchement IA quand le service MCP existera) ?
3. **Repères (objectifs calories et macros) :** dans le périmètre maintenant, ou plus tard ? Je propose maintenant, en facultatif.
