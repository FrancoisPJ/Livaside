<!-- Source : Paperclip LIV-4, document `architecture` -->

# Architecture du service MCP — décision

**Statut : décidé et clos (révision 3, 4 octobre 2026).** Aucun code, aucune infrastructure engagée.
Ce document fixe la cible et les contraintes que la v1 locale respecte pour ne pas créer d'impasse.

> **Révision 3 : réconciliation finale avec la spec MVP (LIV-2, révision 2) et la validation LIV-9.**
> La révision 2 de ce document et la réponse de l'iOS Engineer se sont croisées à trois secondes
> d'intervalle. Quatre écarts restaient ouverts ; ils sont tous tranchés ici :
>
> 1. **Contrat de synchro** : instantané complet pour **tout**, y compris `Meal`. Pas de différentiel (§2).
> 2. **C5** : maintenue dans la v1 en semaine 4, comme planifié par l'iOS Engineer (D18), mais non
>    bloquante pour la démo — si elle glisse, rien ne casse (§5).
> 3. **`training_load`** : `null` tant que l'app ne lit pas la fréquence cardiaque ; le service
>    expose un **volume** (minutes actives, séances). Aucun élargissement de périmètre (§4).
> 4. **v1.5** : l'app n'écrit jamais dans iCloud. L'export sort par la feuille de partage, et c'est
>    l'utilisateur qui l'envoie sur son Mac (§6), ce qui respecte 5.1.3(ii).
>
> **Aucune contrainte nouvelle n'est imposée à l'app.** Tout ce que demande ce document figure déjà
> dans la spec MVP (D16–D18, §3.0, §6).

---

## 1. La décision en dix lignes

1. **Le téléphone reste la source de vérité, pour toujours.** Le serveur MCP ne sera jamais la base
   maître : c'est une **réplique dérivée**, reconstructible intégralement par un re-push depuis
   l'iPhone. C'est ce qui supprime la notion même de « migration douloureuse ».
2. **La v1 n'a besoin d'aucun backend.** Rien dans le MCP ne justifie d'en ajouter un maintenant.
3. **La v1 respecte 5 contraintes de modèle de données** (§5), validées par l'iOS Engineer et déjà
   intégrées à la spec MVP. Les omettre aurait coûté une réécriture du modèle plus tard.
4. **Étape intermédiaire recommandée (v1.5) : serveur MCP local, zéro infrastructure, zéro euro.**
   Un petit binaire sur le Mac du fondateur / des beta-testeurs, qui lit un export JSON que
   l'utilisateur a lui-même envoyé de son iPhone vers son Mac. Ça fait tourner le différenciateur en quelques jours, avec de vrais
   utilisateurs, avant de dépenser quoi que ce soit.
5. **Cible (v2) : un serveur MCP distant HTTPS, OAuth 2.1, hébergé en UE.** Ce n'est pas un choix
   esthétique : **ChatGPT ne sait se connecter qu'à des serveurs MCP distants en HTTPS, avec OAuth
   2.1 et Dynamic Client Registration obligatoires** — il refuse les jetons bearer statiques et ne
   parle pas aux serveurs locaux. La promesse « l'IA de votre choix » impose donc un service distant.
6. **L'autorisation se décide dans l'app, pas sur une page web.** Flux de pairage par code :
   l'utilisateur ouvre Livaside, choisit les portées et la durée, obtient un code, le colle chez son
   assistant. Pas de compte, pas de mot de passe, pas d'email. Le consentement reste physiquement
   sur le téléphone.
7. **Lecture seule au départ.** Les outils d'écriture (« note ce repas ») sont une portée séparée,
   consentie séparément, plus tard.
8. **Le relais ne reçoit qu'une projection agrégée**, pas les échantillons bruts HealthKit.
9. **Ce que ça ferme, dit franchement : le chiffrement de bout en bout.** Un serveur qui répond à
   des questions doit pouvoir lire les données. On ne promettra donc jamais du E2EE sur le chemin
   MCP. C'est le vrai prix de la compatibilité ChatGPT. → **escalade CEO (§8).**
10. **Rien de tout ça ne démarre avant que la démo de suivi soit validée.** Estimation v2 :
    ~3–4 semaines de dev concentré, ~0–25 €/mois d'infra jusqu'à quelques centaines d'utilisateurs.

---

## 2. Où vivent les données

### Principe : une source de vérité, une projection

```
┌──────────────────────────────┐
│  iPhone — SwiftData (local)  │   ← SOURCE DE VÉRITÉ
│  Apple Health + saisies      │      Tout. Pour toujours.
└───────────────┬──────────────┘
                │  push sortant uniquement, idempotent, chiffré en transit
                │  déclenché par l'app, jamais par le serveur
                ▼
┌──────────────────────────────┐
│  Relais Livaside (UE)        │   ← RÉPLIQUE DÉRIVÉE
│  projection par utilisateur  │      Jetable. Reconstructible.
└───────────────┬──────────────┘
                │  MCP Streamable HTTP + OAuth 2.1
                ▼
      Claude · ChatGPT · autre assistant
```

Le relais n'a **aucune** autorité : il ne crée pas de donnée, ne corrige pas de donnée, ne renvoie
rien vers le téléphone. Il est en lecture seule vis-à-vis de l'utilisateur et en écriture seule
vis-à-vis de l'app. Trois conséquences directes :

- **Pas de synchronisation bidirectionnelle à écrire.** C'est la partie coûteuse et buggée des
  architectures locales-puis-cloud. On ne l'écrit jamais.
- **Pas de résolution de conflits.** Il n'y a qu'un seul écrivain.
- **Pas de migration de schéma côté serveur.** Si le schéma de la projection change, on vide et on
  re-push. L'opération coûte quelques secondes par utilisateur.

### Pourquoi pas tout garder sur le téléphone

Parce qu'un iPhone n'est pas un serveur HTTPS joignable. Pas d'adresse stable, pas de certificat,
pas de processus en arrière-plan garanti par iOS. Un assistant distant qui interroge directement le
téléphone est impossible sans tunnel permanent — ce qui consomme la batterie, casse dès que le
réseau change, et ne survivrait pas à la revue App Store.

### Pourquoi pas CloudKit comme relais

CloudKit synchronise élégamment entre appareils d'un même utilisateur Apple, mais un serveur MCP
tiers ne peut pas lire une base CloudKit privée : l'accès passe par l'identité iCloud de
l'utilisateur, dans un contexte Apple. On garde CloudKit comme option pour la **synchro
multi-appareils** (sujet distinct), pas comme socle du MCP.

### Ce qui est poussé — et ce qui ne l'est pas

| Poussé vers le relais | Gardé uniquement sur le téléphone |
|---|---|
| Résumés journaliers (sommeil, volume d'entraînement, nutrition, poids) | Échantillons bruts HealthKit (FC seconde par seconde, pas à pas) |
| Séances : type, durée, énergie active, source (pas de FC en v1) | Traces GPS, itinéraires |
| Nuits : coucher, lever, durée par stade | Données de santé non liées aux 4 piliers |
| Repas : horodatage, kcal, macros, libellé | Notes libres (sauf si l'utilisateur l'active) |
| Mesures corporelles, poids | Identifiants Apple Health, identifiants d'appareil |
| Profil minimal : objectifs, unités, fuseau | Nom, email, contacts |

Ordre de grandeur : cette projection pèse **quelques centaines de Ko par utilisateur et par an**.
Mille utilisateurs tiennent largement sous le gigaoctet. L'infrastructure reste minuscule — c'est
voulu, et c'est ce qui rend le coût négligeable.

### La nature du push : un instantané complet, jamais un delta

**Décision : chaque push remplace intégralement la projection du relais, pour toutes les entités,
`Meal` compris. Ce n'est pas une fusion incrémentale.** Le document poussé est l'export complet (C5),
le relais écrase ce qu'il avait, point.

C'est le choix le plus important de ce document après « le téléphone est maître », parce qu'il
*supprime* du travail au lieu d'en créer :

- **Les suppressions se propagent gratuitement.** Une séance effacée dans Apple Santé disparaît du
  miroir, donc de l'instantané, donc du relais. Aucun champ `deletedAt` n'est nécessaire sur les
  miroirs. Avec une fusion incrémentale, « ligne absente » ne veut pas dire « ligne supprimée » : le
  relais garderait des séances fantômes **indéfiniment**, et c'est le genre de bug qu'on ne
  diagnostique qu'en production, sur les données de quelqu'un d'autre.
- **Le push est idempotent par construction.** Rejouable, interruptible, sans curseur à maintenir ni
  état de synchro à réconcilier entre l'iPhone et le relais.
- **C'est abordable précisément à cause de l'ordre de grandeur ci-dessus.** Quelques centaines de Ko
  par an, compressés : un push complet coûte moins qu'une photo. L'incrémental ne devient
  intéressant qu'à plusieurs années de volume — et la parade sera alors une fenêtre glissante
  (les 90 derniers jours en entier + un archivage au-delà), pas une fusion ligne à ligne.

**Pourquoi `Meal` aussi, alors que la spec proposait un différentiel pour lui (LIV-2 §6.1).** C'est la
seule donnée non reconstructible, mais pour l'appareil seulement : sur le téléphone, sa conservation
est garantie par la base locale et la sauvegarde de l'iPhone, pas par le relais. Côté relais, un repas
est une ligne comme une autre, et quelques repas par jour pèsent moins de 100 Ko par an. Un
différentiel ajouterait un curseur, des pierres tombales côté serveur et un deuxième chemin de code
pour un gain nul. **Un seul mécanisme, pour tout.** Conséquence pour l'app : la règle « `updatedAt`
ne bouge que si le contenu change » (spec §3.0) n'est plus porteuse pour le MCP. Elle reste correcte et
utile pour le diagnostic ; l'iOS Engineer est libre de la simplifier si elle coûte du temps à la démo.

Le prix assumé : le relais ne conserve aucun historique antérieur au dernier push. C'est cohérent
avec « réplique dérivée et jetable » — l'historique vit sur le téléphone et dans Apple Santé.

---

## 3. Comment un assistant externe se connecte

### Transport et protocole

- **Streamable HTTP**, le transport MCP courant. Le transport SSE historique est déprécié, on ne
  l'implémente pas.
- Serveur **sans état** autant que possible : chaque requête porte son jeton, aucune session
  persistante à gérer. Moins de code, moins de pannes.

### Autorisation : OAuth 2.1, parce qu'on n'a pas le choix

La révision 2026-07-28 de la spécification MCP impose à un serveur distant :

| Exigence | Référence | Ce que ça veut dire concrètement |
|---|---|---|
| Métadonnées de ressource protégée | RFC 9728 | `GET /.well-known/oauth-protected-resource` annonce le serveur d'autorisation |
| Indicateurs de ressource | RFC 8707 | le client envoie `resource=` ; le serveur **rejette** tout jeton émis pour quelqu'un d'autre |
| OAuth 2.1 + PKCE | — | flux code d'autorisation avec PKCE, obligatoire |
| Enregistrement dynamique de client | RFC 7591 | **exigé par ChatGPT**, qui refuse les jetons bearer statiques |

Il n'y a pas de version simplifiée. Un « jeton d'API à coller » ne fonctionnera pas avec ChatGPT, et
sera refusé par les connecteurs des clients conformes. Autant le faire correctement une fois.

### Le point de design qui compte : l'autorisation se décide sur le téléphone

Le réflexe serait de construire des comptes (email, mot de passe, réinitialisation, support).
Ce serait renier « pas de compte utilisateur » et ajouter la partie la plus ennuyeuse d'un backend.

**Flux de pairage retenu :**

```
1.  App Livaside → « Connecter un assistant »
    L'utilisateur choisit : quelles portées, pour combien de temps.
    L'app affiche un code court (6–8 caractères, valable 10 min).

2.  Assistant (Claude / ChatGPT) → ajoute le connecteur Livaside
    Flux OAuth standard. La page d'autorisation demande une seule chose : le code.

3.  Le serveur relie le code à l'identité de l'appareil
    et émet un jeton limité aux portées et à la durée choisies à l'étape 1.

4.  L'app affiche la connexion active, et peut la révoquer d'un geste.
```

L'identité de l'utilisateur est une **paire de clés générée sur l'appareil** au premier push,
stockée dans le Trousseau (Secure Enclave). Le serveur ne connaît qu'une clé publique et un
identifiant opaque. Ni nom, ni email, ni mot de passe, ni rien à voler dans une base de comptes.
Si l'utilisateur perd son téléphone sans sauvegarde, il perd son identité relais — et c'est
acceptable : les données de référence sont sur le téléphone, le relais est jetable.

> **Conséquence assumée :** l'utilisateur doit avoir l'app ouverte pour autoriser un assistant.
> C'est exactement ce qu'on veut — le consentement est un geste délibéré, pas une case à cocher
> dans un navigateur.

### Portées

Granularité par pilier, lecture seule, lisibles par un humain sur l'écran de consentement :

| Portée | Donne accès à |
|---|---|
| `sleep:read` | nuits, durées, stades, régularité |
| `workouts:read` | séances, durée, énergie active, volume |
| `nutrition:read` | repas, calories, macros |
| `body:read` | poids, mesures corporelles |
| `profile:read` | objectifs, unités préférées, fuseau |

Pas de portée `*`. Un assistant qui veut tout demande les cinq, et l'utilisateur voit les cinq.
Les portées d'écriture (`*:write`) sont hors périmètre v2 et feront l'objet d'une décision séparée.

---

## 4. Les requêtes à servir, et ce qu'elles impliquent

### Principe de conception : peu d'outils, larges et paramétrés

Un catalogue de trente outils étroits noie l'assistant, gonfle le contexte et dégrade ses réponses.
On vise **sept outils**, chacun couvrant une famille de questions.

### Les deux questions de référence, décomposées

**« Comment j'ai dormi cette semaine ? »**
→ un seul appel : `get_daily_summary(from, to, metrics: ["sleep"])`.
Implique : des **journées locales** bien définies (une nuit traverse minuit), une **moyenne
comparable** à celle affichée dans l'app, et la **distinction entre zéro et absence de donnée**
(« tu as dormi 0 h mardi » est faux et détruit la confiance ; « pas de donnée mardi » est honnête).

**« Adapte ma séance de demain »**
→ **ce n'est pas une requête de données, c'est un raisonnement.** Le serveur MCP ne doit surtout pas
essayer d'y répondre : c'est le travail de l'assistant, et c'est précisément le positionnement de
Livaside (pas d'IA imposée dans l'app). Le serveur doit livrer, **en un seul appel**, tout ce qu'il
faut pour raisonner :

```
get_readiness_context(date)
  → volume d'entraînement 7 j / 28 j (minutes actives, nombre de séances) et leur rapport
  → training_load: null, reason: "heart_rate_not_collected" (voir ci-dessous)
  → séances des 14 derniers jours (type, durée, intensité)
  → sommeil des 3 dernières nuits + écart à la moyenne 30 jours
  → poids et tendance
  → apports de la veille (kcal, protéines)
  → objectifs déclarés
  → trous de données explicites
```

Un appel, une réponse compacte. C'est ce qui fait la différence entre un assistant qui répond en
trois secondes et un qui fait douze allers-retours.

**Sur la charge d'entraînement : `null`, et c'est décidé ici.** Une charge au sens propre
(durée × intensité relative) demande la fréquence cardiaque ou un RPE, et la v1 ne lit ni l'une ni
l'autre (spec §8). Le service expose donc le **volume** (minutes actives et séances sur 7 j / 28 j),
nommé comme tel, et `training_load: null` avec sa raison. C'est honnête, ça ne coûte rien, et ça ne
change pas le périmètre de la démo : **pas d'arbitrage CEO nécessaire**, puisque rien ne bouge. Lire
la FC sera une décision de périmètre produit, à prendre après la démo si les utilisateurs de la v1.5
la réclament. Le service l'exploitera alors sans changer d'outil, puisque le champ existe déjà.

### Surface d'outils retenue

| Outil | Rôle |
|---|---|
| `get_daily_summary(from, to, metrics[])` | le cheval de bataille — une ligne par jour local |
| `get_sleep(from, to)` | détail par nuit : coucher, lever, stades, régularité |
| `get_workouts(from, to, type?)` | séances individuelles |
| `get_nutrition(from, to, granularity)` | repas ou agrégats journaliers |
| `get_body(from, to)` | poids et mesures |
| `get_trends(metric, window, compare_to)` | moyennes glissantes, delta vs période précédente |
| `get_readiness_context(date)` | le bundle décrit ci-dessus |

Plus deux **ressources** MCP (pas des outils) : le **dictionnaire de données** (métriques, unités,
définitions des agrégats) et le **profil** (objectifs, fuseau, unités). L'assistant les lit une fois
et sait interpréter les chiffres — sans brûler un appel d'outil.

### Trois règles non négociables sur les réponses

1. **Toute réponse porte ses unités et son fuseau.** Jamais un nombre nu.
2. **Les trous sont explicites.** Un jour sans donnée renvoie `null` + la raison si on la connaît
   (`no_data` / `not_authorized` / `partial`), jamais `0`.
3. **Les chiffres du MCP sont identiques à ceux des graphiques de l'app.** Si l'assistant annonce
   7 h 12 de moyenne et que l'écran Tendances affiche 7 h 24, l'utilisateur cesse de faire confiance
   aux deux. Cela impose que la **définition** des agrégats journaliers soit écrite une fois, dans
   la spec, et appliquée des deux côtés (contrainte C4, §5).

---

## 5. Les contraintes imposées à la v1 — **validées et intégrées** (LIV-9, spec LIV-2 rév. 2)

C'est le seul endroit où le MCP touche au travail de la démo. Tout le reste attend.

| | Contrainte | Statut | Où c'est dans la spec |
|---|---|---|---|
| **C1** | Identité stable, provenance, horodatage | **Intégrée** | §3.0 : `uid` déterministe, `sourceRaw` / `sourceBundleID` / `sourceName`, `createdAt` / `updatedAt` / `lastSyncedAt` |
| **C2** | Instant absolu + fuseau + jour local | **Intégrée** | §3.0 et D17 : `dayKey`, `timeZoneID`, `timeZoneIsExact` |
| **C3** | Unités canoniques SI en base | **Intégrée** | D10 |
| **C4** | Définition des agrégats écrite une fois | **Intégrée** | §5.1–5.4 |
| **C5** | Sérialiseur JSON complet et versionné | **Planifiée, semaine 4, non bloquante** | D18, §6.4 |

**Le coût de la démo est de ~1,5 jour, dont 1 pour C5.** Rien d'autre.

### C1 : identité, provenance, horodatage

J'adopte les trois amendements de l'iOS Engineer, qui sont meilleurs que ma formulation initiale :

- **`uid` déterministe** (`sleep:<dayKey>`, `workout:<healthKitUUID>`, `body:<kind>:<healthKitUUID>`,
  `meal:<UUID>`). Un `UUID()` aléatoire aurait été réattribué à chaque reconstruction du miroir et
  aurait dupliqué chaque push. **Le relais prend `uid` comme clé primaire, sans transformation.**
- **Provenance en champs plats**, interrogeable en `#Predicate`. Le MCP pourra répondre « d'après ton
  Apple Watch » plutôt que « d'après HealthKit ».
- **`deletedAt` sur `Meal` seulement.** Avec l'instantané complet (§2), les suppressions se propagent
  sans pierre tombale, sur toutes les entités. `deletedAt` reste un filet de sécurité produit
  (annulation), sans rôle pour le MCP.

### C2 : fuseau de l'événement

`timeZoneID` + `timeZoneIsExact` sur tout enregistrement horodaté (D17). Le booléen ajouté par l'iOS
Engineer est juste : HealthKit ne fournit `HKMetadataKeyTimeZone` que si la source l'a écrit. **Le
service l'exposera tel quel** : une heure locale calculée avec `timeZoneIsExact == false` sera signalée
comme approximative dans la réponse, jamais présentée comme une mesure.

Règle à tenir côté app (déjà dans la spec, §4) : `dayKey` et `timeZoneID` sont **écrits une fois par
ligne** et jamais recalculés lors d'une re-synchro du même `uid`. C'était le seul point non
récupérable du document, et il est couvert.

### C3 : unités

Secondes, kilogrammes, mètres, kcal, grammes. `bodyFatPercentage` est une fraction 0–1 et le
dictionnaire de données le déclarera comme tel.

### C4 : définitions des agrégats

Les définitions qui font foi sont celles de la spec, **et le service les reprendra mot pour mot** :

- **Sommeil = union des intervalles** des stades `asleep*`, sur la source retenue pour la nuit,
  rattachée au jour du réveil (§5.1). Pas la somme des stades : sur des données réelles, les
  échantillons se recouvrent et la somme produit des nuits de 14 heures.
- Doublons de séances regroupés à 50 % de recouvrement, seul le représentant compte (§5.2).
- Mesures : valeur la plus récente du jour (§5.3). Trous explicites (§5.4).
- **`DailySummary` n'est pas persisté** (D9) : c'est un type valeur recalculé, que le sérialiseur
  émet. J'accepte. Une table persistée aurait dû être invalidée sur deux chemins, et la première
  invalidation manquée aurait produit exactement la divergence de chiffres que C4 interdit.

**Le jour de rattachement d'une séance** (début ou fin pour une séance qui passe minuit) n'a pas
besoin d'être tranché par moi. Par l'engagement E2 ci-dessous, le service lit le `dayKey` produit par
`DayKey.swift` comme une clé opaque : quelle que soit la règle de l'app, les chiffres seront identiques
des deux côtés. Ma préférence, **le jour du début**, est une recommandation, pas une contrainte.

### C5 : sérialiseur JSON versionné

Le plan de l'iOS Engineer est meilleur que le retrait que je proposais en révision 2, et je le
retiens : DTO `Codable` distincts des `@Model`, `schema_version` entier, `ExportBuilder`, test de
round-trip, dictionnaire de données embarqué, sortie par la feuille de partage. **C'est exactement
l'entrée de la v1.5**, sans une ligne d'iOS en plus.

**Il n'est pas bloquant.** Planifié en semaine 4, après les trois écrans. S'il glisse, la démo n'en
souffre pas et l'architecture non plus : C5 ne touche pas au schéma, ne perd rien rétroactivement, et
sur un modèle sans relation (D8), c'est une journée de travail à n'importe quel moment. Il devient
seulement le premier élément du chemin MCP : **sans C5, pas de v1.5.**

### 5.6 — Trois engagements côté serveur

**E1 — Le push est un instantané complet, pour toutes les entités, `Meal` compris** (§2). Pas de
différentiel, pas de pierre tombale côté serveur, pas de curseur.

**E2 — Le serveur groupe par `dayKey`, traité comme une clé opaque.** Il ne recalcule jamais un jour
depuis une `Date`. Une semaine est une énumération de `dayKey`. Conséquence voulue : le service hérite
de l'attribution des jours faite par l'app, cas limites compris, et les chiffres sont identiques à
ceux des graphiques.

**E3 — Aucun identifiant d'appareil ni d'installation en v1.** L'identifiant de pairage sera créé au
moment du consentement (v2), stocké dans le Trousseau, et détruit à la révocation.

### 5.7 — Les champs de diagnostic deviennent des états de réponse

| Situation en base | Ce que l'outil MCP répond |
|---|---|
| `hasStages == false` | `stages: null, reason: "source_has_no_stages"`, **jamais des zéros** |
| `timeAsleepSeconds == nil`, `timeInBed` présent | `time_in_bed` seul, explicitement libellé |
| aucune ligne `SleepNight` | `null, reason: "no_data"` |
| `competingSourceCount > 0` | la source retenue est nommée |
| `isGroupRepresentative == false` | séance exclue des volumes, comme dans l'app |
| `timeZoneIsExact == false` | heure locale marquée `approximate` |

Les trois états d'affichage de la spec (§5.4) deviennent trois états de réponse du MCP. Rien à faire
côté v1 : c'est déjà là.

---

## 6. Le chemin : trois étapes, pas une

### v1 — la démo (en cours, ~4 semaines)

SwiftData local, aucun backend, aucun compte. Les contraintes C1–C4 sont tenues, C5 arrive en
semaine 4 si le planning le permet. **Aucun autre travail MCP.** Le mot « MCP » n'apparaît pas dans
l'app.

### v1.5 — MCP local, zéro infrastructure, zéro euro

L'utilisateur exporte ses données (C5) par la **feuille de partage** et les envoie lui-même sur son
Mac. Le chemin recommandé est **AirDrop**, qui ne passe par aucun cloud. Un petit serveur MCP local
(un paquet npm ou un binaire, lancé par Claude Desktop / Claude Code en stdio) lit ce fichier et
expose les sept outils du §4.

**L'app n'écrit jamais dans iCloud.** Privacy (LIV-5) rappelle la règle 5.1.3(ii) : une app ne peut
pas stocker de données de santé dans iCloud. La feuille de partage laisse l'utilisateur choisir la
destination, comme pour n'importe quel fichier exporté. S'il choisit iCloud Drive, c'est son geste,
pas un stockage de l'app. Ce point est versé à l'avis juridique déjà prévu (LIV-12, point 4). En
attendant, la documentation de la v1.5 recommande AirDrop.

| | |
|---|---|
| **Coût** | ~1 semaine de dev. **0 €/mois.** Aucun serveur, aucun compte, aucune donnée hors de l'appareil de l'utilisateur. |
| **Ce que ça permet** | tester en vrai la surface d'outils, découvrir ce que les assistants demandent réellement, et **montrer le différenciateur** à des beta-testeurs et à des investisseurs. Avec un argument privacy imbattable : les données ne quittent pas la machine. |
| **Ce que ça ferme** | Claude Desktop / Claude Code uniquement, sur Mac. **Pas ChatGPT, pas de mobile.** |

**C'est la bonne première livraison du MCP.** Elle valide le design des outils — la partie qu'on
regretterait d'avoir figée dans une infrastructure payante — avant d'engager un euro ou une semaine
de serveur.

### v2 — MCP distant, la promesse complète

Le relais du §2, l'OAuth du §3, le pairage par code. C'est ce qui ouvre ChatGPT, le mobile, et
« l'IA de votre choix » au sens littéral.

| | |
|---|---|
| **Coût** | ~3–4 semaines de dev concentré (serveur MCP, serveur d'autorisation, endpoint de push, écran de consentement iOS). Infra : **0–25 €/mois** jusqu'à quelques centaines d'utilisateurs. |
| **Ce que ça permet** | la promesse produit, entière. |
| **Ce que ça ferme** | le chiffrement de bout en bout sur le chemin MCP. Des données de santé hébergées. Une obligation de disponibilité. |

**Déclencheur recommandé :** ne pas ouvrir la v2 avant que (a) la démo de suivi soit validée, et
(b) la v1.5 ait tourné chez de vrais utilisateurs. Si personne n'utilise le MCP local, le MCP
distant n'a pas de marché à servir.

---

## 7. Le contrôle utilisateur, par conception

Cinq mécanismes, pas des options :

1. **Rien ne part sans un geste explicite.** Le push n'existe pas tant que l'utilisateur n'a pas
   connecté un assistant. Une installation de Livaside qui n'utilise jamais le MCP n'envoie **aucun
   octet** nulle part — c'est l'état par défaut, et il le reste.
2. **Le consentement se donne dans l'app**, portée par portée, avec une durée (défaut : 90 jours,
   modifiable, renouvelable). Pas de jeton éternel.
3. **Journal d'accès visible**, limité aux métadonnées (quel assistant, quel outil, quand), **jamais le
   contenu** des réponses. « Claude a consulté votre sommeil, il y a 2 h. » C'est la
   fonctionnalité de confiance au meilleur rapport coût/bénéfice de tout ce document : quelques
   lignes côté serveur, un écran côté app, et l'utilisateur *voit* qu'il contrôle.
4. **Révocation immédiate et sans contact.** Un geste dans l'app invalide le jeton. La révocation
   d'une connexion **supprime la projection côté relais** si c'était la dernière.
5. **Suppression totale.** « Déconnecter tout et effacer du serveur » efface la projection et
   l'identité relais. Les données restent sur le téléphone, intactes. L'utilisateur revient à
   l'état local-first d'origine, sans rien perdre.

Deux promesses qu'on ne fera pas, pour ne pas mentir : le chiffrement de bout en bout sur le chemin
MCP (§8), et un accès MCP hors ligne quand le téléphone n'a pas poussé depuis longtemps — la
réponse portera alors une date de fraîcheur explicite.

---

## 8. Escalades

### → CEO : une décision de branche, déjà posée sur le board (LIV-12)

Privacy (LIV-5) a remonté au CEO, dans **LIV-12 point 3**, le choix entre MCP local et MCP hébergé, et
dans **LIV-12 point 4**, l'avis juridique. **Ma recommandation pour ce point 3 :**

1. **Maintenant : la branche locale, et seulement elle (v1.5).** Elle coûte 0 €, garde « Aucune donnée
   collectée » sur la fiche App Store, et laisse la politique de confidentialité vraie telle
   qu'écrite. Elle remplit les cinq conditions de Privacy, dont la plus exigeante : **Livaside n'est
   pas dans la boucle**.
2. **Plus tard : la branche hébergée (v2), sous deux conditions.** La v1.5 doit avoir montré un usage
   réel, et un second avis juridique doit avoir été obtenu. Ce second avis devient obligatoire dès
   qu'on héberge : responsabilité de traitement de données de santé (RGPD art. 9), analyse
   d'impact, régime HDS à confirmer.

Ce que la branche hébergée fait payer, dit franchement : Livaside **entre dans la boucle**. On ne peut
plus dire « nous ne partageons pas vos données », la fiche App Store change, et le chiffrement de bout
en bout devient impossible sur le chemin MCP (un serveur qui répond doit lire). En échange, elle seule
ouvre ChatGPT et le mobile. **C'est un arbitrage de positionnement, et il revient au CEO, mais il
n'est requis qu'à l'ouverture de la v2**, pas avant. Rien dans la v1 ni dans la v1.5 n'en dépend.

**Plus aucune autre escalade.** La charge d'entraînement, que la spec remontait au CEO, n'en est pas
une : l'option retenue (`training_load: null`, §4) ne change aucun périmètre.

### → iOS Engineer : **clos**

C1–C5 validées (LIV-9) et intégrées à la spec (D16–D18, §3.0, §6). Les trois points que l'iOS Engineer
me demandait d'acter le sont :

1. Contrat de synchro : **instantané complet pour tout, `Meal` compris** (§2). C'est plus simple que la
   proposition de la spec, et ça n'ajoute rien côté app.
2. Sommeil : **union des intervalles** (§5, C4).
3. `training_load` : **`null` en v1, volume exposé à la place**, sans escalade (§4).

**Aucune contrainte nouvelle n'est imposée à l'app.**

### → Privacy & Compliance : intégré

Les cinq conditions de LIV-5 (`policy` §6) sont tenues par conception : déclenchement par
l'utilisateur (§7.1), consentement distinct et révocable (§7.2, §7.4), périmètre restreint (§2),
journal limité aux métadonnées (§7.3). « Livaside n'est pas dans la boucle » est vrai en v1.5 et
cesse de l'être en v2, d'où l'escalade ci-dessus. Le risque 1.4.1 est retenu : le MCP se présente
comme « vos données, accessibles à l'outil de votre choix », **jamais comme un coach IA**.

---

## 9. Questions restant ouvertes (aucune ne bloque la v1 ni la v1.5)

1. **HDS et responsabilité de traitement en cas d'hébergement**, à verser au second avis juridique
   et à poser seulement si la v2 s'ouvre (LIV-12, points 3–4).
2. **Export vers iCloud Drive par l'utilisateur** : à confirmer dans le premier avis juridique
   (LIV-12, point 4) qu'un export déclenché par l'utilisateur sort bien du champ de 5.1.3(ii). La v1.5
   recommande AirDrop en attendant.
3. **Texte de l'écran de pairage v2**, à rédiger par Privacy à l'ouverture de la v2.

---

## 10. Ce que ce document garantit

- **La v1 ne crée pas d'impasse.** Le téléphone reste maître et le relais est une réplique jetable.
  Il n'y aura jamais de migration de données à faire, seulement un re-push.
- **Toutes les contraintes imposées à l'app sont validées par l'iOS Engineer** (LIV-9) et déjà
  écrites dans la spec (D16–D18). Coût pour la démo : ~1,5 jour, dont 1 jour (C5) qui peut glisser
  sans conséquence.
- **Le seul point non récupérable**, le fuseau d'un événement passé, est couvert dès la v1
  (`timeZoneID` + `timeZoneIsExact`, écrits une fois).
- **Le différenciateur peut être montré sans dépense ni hébergement** grâce à la v1.5 locale, dans le
  scénario de conformité le plus simple.
- **La seule décision irréversible restante**, héberger ou non des données de santé, donc renoncer
  ou non à « Livaside n'est pas dans la boucle », est sur le board (LIV-12, point 3), avec une
  recommandation. Elle n'est requise qu'à l'ouverture de la v2.
