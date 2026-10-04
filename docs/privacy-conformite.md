<!-- Source : Paperclip LIV-5, document `policy` -->

# Base privacy et conformité santé — Livaside v1

**Statut : aucun blocage structurel identifié pour une publication App Store.** L'architecture
retenue (100 % local, SwiftData, pas de compte, pas de backend) est le scénario le plus simple à
défendre devant la revue Apple et sous le RGPD. Les trois points qui demandent une décision avant
publication sont listés au § 9 — aucun ne concerne la démo.

**Ce qui est demandé à l'iOS Engineer pour la démo : 1 clé Info.plist, 1 ligne de configuration
SwiftData, 1 écran d'explication avant la fenêtre système, 1 bouton « effacer mes données ».**
Rien d'autre. Détail au § 2.

---

## 1. Verdict publication

| Sujet | Risque de refus | Pourquoi |
|---|---|---|
| Lecture HealthKit (sommeil, séances, poids) | **Faible** | Usage conforme à 2.5.1 : « HealthKit should be used for health and fitness purposes and integrate with the Health app ». |
| Stockage 100 % local | **Nul** | Aucune collecte au sens Apple (§ 5.1). Supprime la quasi-totalité des obligations. |
| Pas de compte utilisateur | **Nul**, c'est un atout | Guideline 5.1.1(v) : « If your app doesn't include significant account-based features, let people use it without a login. » |
| Politique de confidentialité | **Bloquant si absente** | 5.1.1(i) exige un lien dans App Store Connect **et** dans l'app. Texte fourni au § 3. |
| Accès MCP / IA tierce | **Réel, maîtrisable** | 5.1.2(i) : « You must clearly disclose where personal data will be shared with third parties, **including with third-party AI**, and obtain explicit permission before doing so. » Conditions au § 6. |
| Formulations santé dans l'app et le marketing | **Réel, maîtrisable** | 1.4.1 : les apps pouvant servir à diagnostiquer ou traiter sont examinées avec plus de sévérité. Règles de wording au § 5.4. |
| Sync iCloud / CloudKit des données de santé | **Bloquant si fait** | 5.1.3(ii) : les apps « may not store personal health information in iCloud ». Interdit CloudKit pour ce store. § 2.1.3. |

Aucun de ces points n'impose de travail avant la démo. Le seul effort immédiat est au § 2.1
(quatre éléments) et au § 3 (textes déjà rédigés, à héberger quand le site existe).

---

## 2. Exigences de stockage et de consentement — v1

Destinataire : **iOS Engineer** (LIV-2, LIV-3, LIV-8).

### 2.1 Obligatoire

**2.1.1 — Purpose string HealthKit**

`NSHealthShareUsageDescription` est obligatoire : sans elle, l'app **plante** à l'appel de
`requestAuthorization`. Guideline 5.1.1(ii) : « Ensure your purpose strings clearly and completely
describe your use of the data. » Texte à utiliser :

> Livaside lit votre sommeil, vos séances et votre poids dans l'app Santé pour afficher vos
> tendances. Ces données restent sur votre iPhone.

Ne **pas** déclarer `NSHealthUpdateUsageDescription` en v1 : l'app ne doit rien écrire dans Santé
(§ 2.1.2). Déclarer une permission d'écriture non utilisée est un signal négatif en revue et
contredit la minimisation (5.1.1(iii)).

**2.1.2 — Lecture seule, et périmètre de types fermé**

Guideline 5.1.1(iii) : « Apps should only request access to data relevant to the core functionality
of the app and should only collect and use data that is required to accomplish the relevant task. »

Liste close des types demandés en v1 — ne rien ajouter sans me le signaler :

- Sommeil : `HKCategoryTypeIdentifierSleepAnalysis`
- Séances : `HKObjectType.workoutType()`, `activeEnergyBurned`, `distanceWalkingRunning`
- Poids et mesures : `bodyMass`, `bodyFatPercentage`, `leanBodyMass`, `height`
- Récupération (si les graphiques l'exigent) : `restingHeartRate`, `heartRateVariabilitySDNN`

Explicitement **hors périmètre v1** :

- Les **types nutrition** (`dietaryEnergyConsumed`, `dietaryProtein`, …) : la saisie est manuelle
  en v1, donc la permission n'a pas de justification. On ne demande pas une permission qu'on
  n'utilise pas.
- Les **caractéristiques** (`dateOfBirth`, `biologicalSex`, `bloodType`, `fitzpatrickSkinType`) :
  inutiles tant qu'aucun calcul ne les exige. Si un calcul de dépense énergétique les requiert plus
  tard, on prendra `dateOfBirth` et `biologicalSex` uniquement — jamais `bloodType`.
- Les **dossiers médicaux** (`HKClinicalType`, Health Records API) : jamais. Ils déclenchent un
  niveau de revue Apple distinct et bien plus lourd, pour aucun bénéfice produit ici.

**2.1.3 — Store local strictement local**

`ModelConfiguration` **sans** `cloudKitDatabase`. Pas de CloudKit, pas d'App Group partagé avec un
service distant, pas de fichier écrit dans un conteneur iCloud Drive. Guideline 5.1.3(ii) : les apps
« may not store personal health information in iCloud ».

À noter : SwiftData active CloudKit automatiquement si l'entitlement iCloud est présent et que la
configuration par défaut est utilisée. C'est le piège principal — vérifier que l'entitlement
CloudKit **n'est pas** dans le target.

Cas distinct de la sauvegarde système (iCloud Backup) : voir § 9.2, décision à prendre, pas un
blocage.

**2.1.4 — Zéro réseau**

En v1 l'app ne doit faire **aucune** requête réseau : pas d'analytics, pas de SDK de crash, pas de
polices distantes, pas de vérification de version. C'est ce qui permet de déclarer « Data Not
Collected » dans les App Privacy Details (§ 5.2) — la définition Apple de « collect » est
« transmitting data off the device », et « data that is processed only on device is not "collected"
and does not need to be disclosed ».

Conséquence pratique : **toute** ajout ultérieur d'un SDK tiers me revient avant intégration, parce
qu'il change la déclaration App Store et la politique de confidentialité.

**2.1.5 — Fonctionner sans permission Santé**

Guideline 5.1.1(iv) : « Where possible, provide alternative solutions for users who don't grant
consent. » L'app doit rester utilisable si l'utilisateur refuse Santé : saisie manuelle du poids,
des séances et des repas. C'est déjà le cas pour la nutrition ; il faut que ce soit vrai partout.

Contrainte technique liée : **HealthKit ne dit pas si une lecture a été refusée**. Apple :
« your app cannot determine whether or not a user has granted permission to read data. If you are
not given permission, it simply appears as if there is no data of the requested type ». Donc pas de
message « vous avez refusé l'accès » — il serait faux une fois sur deux. Afficher un état neutre
(« aucune donnée pour cette période ») avec un lien vers Réglages › Santé.

**2.1.6 — Effacement dans l'app**

Guideline 5.1.1(i) : la politique doit « describe how a user can revoke consent and/or request
deletion of the user's data ». Un bouton « Effacer toutes mes données de Livaside » qui vide le
store SwiftData, avec confirmation. Deux lignes de code, et c'est la preuve concrète de la promesse
« vos données vous appartiennent ».

**2.1.7 — Pas de valeurs de santé dans les logs**

Aucune valeur de santé en `print` ou `os_log` interpolé non privé. Les logs appareil sont lisibles
par d'autres processus et remontent dans les diagnostics. Les valeurs numériques ne sont **pas**
masquées automatiquement par `os_log` : utiliser `privacy: .private` ou ne rien logger.

### 2.2 Recommandé

- **Écran d'explication avant la fenêtre système.** Une page qui dit ce qu'on lit et pourquoi, puis
  un bouton qui déclenche la feuille HealthKit. Réduit nettement les refus, et le refus est
  définitif côté utilisateur (il faut passer par Réglages ensuite). Conforme aux HIG Apple
  (« Accessing private data »).
- **Demander au moment de l'usage**, pas au lancement. Une permission demandée dans un contexte
  compris est accordée ; demandée à froid, elle est refusée.
- **Un seul appel `requestAuthorization`** avec la liste complète du § 2.1.2, pas quatre feuilles
  successives.
- **Protection de fichier.** Le niveau par défaut
  (`NSFileProtectionCompleteUntilFirstUserAuthentication`) est acceptable. Passer en
  `completeUnlessOpen` si une tâche de fond doit écrire ; sinon, ne pas y toucher.
- **Marquer la provenance de chaque donnée** (`healthKit` / `manuel`) dans le modèle SwiftData.
  Nécessaire pour l'export (§ 4) et pour ne jamais réécrire dans Santé une donnée venue de Santé.
- **Écran « Vos données » dans les réglages de l'app**, qui dit en trois phrases où sont les données
  et propose export + effacement. C'est le même texte que le § 3.1 — zéro coût de rédaction.

### 2.3 Peut attendre

- Verrouillage de l'app par Face ID. Utile, pas une exigence : iOS protège déjà le store.
- Chiffrement applicatif du store au-delà de la Data Protection iOS. Redondant sans backend.
- Journal d'accès interne, rétention paramétrable, purge automatique.
- Tout ce qui concerne la sync multi-appareils : le jour où elle arrive, elle rouvre le § 5.1.3(ii)
  et la politique de confidentialité en entier. À traiter comme un chantier privacy à part entière,
  pas comme une fonctionnalité technique.

---

## 3. Politique de données en langage clair

Deux textes. Le § 3.1 est l'écran in-app (court). Le § 3.2 est la politique complète à héberger —
Apple exige une URL dans App Store Connect **et** un accès dans l'app (5.1.1(i)).

### 3.1 Écran in-app « Vos données » — texte prêt

> **Vos données restent sur votre iPhone.**
>
> Livaside n'a pas de serveur, pas de compte, pas de mot de passe. Votre sommeil, vos séances, vos
> repas et votre poids sont enregistrés dans l'app, sur votre appareil. Nous n'y avons pas accès.
>
> Nous ne vendons rien, nous ne partageons rien, nous ne mesurons pas votre usage de l'app.
>
> Vous pouvez exporter vos données à tout moment dans un fichier lisible, et tout effacer en une
> fois. Supprimer Livaside supprime aussi les données qu'elle contient.
>
> [Exporter mes données]  [Effacer mes données]  [Politique complète]

### 3.2 Politique de confidentialité — version publiable

> # Politique de confidentialité de Livaside
>
> *Dernière mise à jour : [date de publication]*
>
> ## En une phrase
>
> Livaside fonctionne entièrement sur votre iPhone. Nous ne recevons aucune de vos données de santé,
> parce qu'il n'y a nulle part où les envoyer.
>
> ## Quelles données Livaside utilise
>
> - **Ce que vous saisissez** : vos repas, votre poids, vos mesures, vos séances.
> - **Ce que Livaside lit dans l'app Santé d'Apple**, si vous l'autorisez : votre sommeil, vos
>   séances, votre poids et vos mesures corporelles. Vous choisissez quoi autoriser, type par type,
>   dans la fenêtre d'Apple. Vous pouvez revenir sur ce choix à tout moment dans Réglages › Santé ›
>   Livaside.
>
> Livaside ne demande ni votre nom, ni votre email, ni votre date de naissance. Il n'y a pas de
> compte à créer.
>
> ## Où ces données sont stockées
>
> Sur votre iPhone, dans l'espace de stockage réservé à l'application, protégé par le chiffrement
> d'iOS. Livaside ne les copie pas sur un serveur : nous n'en avons aucun.
>
> ## Ce que nous ne faisons pas
>
> - Nous ne vendons pas vos données, et nous ne les louons à personne.
> - Nous ne les utilisons pas pour de la publicité ou du ciblage.
> - Nous ne mesurons pas votre usage de l'app : pas d'outil d'analyse, pas d'identifiant publicitaire.
> - Nous ne faisons aucune requête vers Internet pendant que vous utilisez l'app.
>
> ## Exporter vos données
>
> À tout moment, depuis les réglages de l'app, vous pouvez produire un fichier contenant tout ce que
> Livaside connaît de vous, dans un format ouvert et lisible par d'autres logiciels. Vous choisissez
> où l'envoyer. Nous n'en recevons pas de copie.
>
> ## Effacer vos données
>
> Depuis les réglages de l'app : « Effacer mes données » supprime définitivement le contenu de
> Livaside. Supprimer l'application supprime également ces données. Dans les deux cas, ce que
> contient l'app Santé d'Apple n'est pas touché : il vous appartient et reste chez Apple.
>
> ## Nous contacter
>
> [adresse de contact] — une question sur vos données obtient une réponse sous 30 jours.
>
> ## Si cette politique change
>
> Si une version future de Livaside envoie des données hors de votre appareil, nous le dirons
> explicitement, avant, et nous vous demanderons votre accord. Ce ne sera jamais activé par défaut.

**Points de rédaction à tenir** : pas de « nous pouvons être amenés à », pas de « partenaires de
confiance », pas de conditionnel. Une politique qui dit « aucune donnée ne sort » n'a pas besoin des
30 paragraphes habituels — et elle reste vraie seulement si le § 2.1.4 est respecté.

**Dépendance** : la politique doit être hébergée à une URL stable avant soumission. À coordonner
avec Content & Marketing (LIV-6), qui construit déjà le site.

---

## 4. Cadrage de l'export

L'export n'est pas une case à cocher réglementaire ici : comme l'app ne collecte rien, les articles
15 et 20 du RGPD ne créent pas d'obligation à notre charge (§ 7). C'est une **promesse produit** —
« vos données vous appartiennent » — et c'est justement pour ça qu'il faut la tenir sérieusement.

### 4.1 Obligatoire pour tenir la promesse

- **Complet** : tout ce que contient le store, sans échantillonnage ni troncature de période.
  Un export partiel est pire qu'un export absent, parce qu'il n'est pas vérifiable.
- **Format ouvert** : JSON en format canonique. Le RGPD, art. 20, parle d'un format « structuré,
  couramment utilisé et lisible par machine » — c'est la bonne barre même sans obligation.
- **Auto-descriptif** : chaque valeur porte son **unité** (`kg`, `kcal`, `min`), son **horodatage
  avec fuseau**, et sa **provenance** (`healthKit` ou `manuel`). Un export dont on ne sait pas si
  les poids sont en kg ou en lb est inutilisable.
- **Sortie par la feuille de partage iOS** : l'utilisateur choisit la destination. Aucun envoi
  réseau initié par l'app, jamais de destination par défaut.
- **Hors ligne** : l'export doit fonctionner en mode avion. C'est le test qui prouve qu'il est local.

### 4.2 Recommandé

- **CSV en complément**, un fichier par domaine (`sommeil.csv`, `seances.csv`, `repas.csv`,
  `poids.csv`), dans un `.zip` avec le JSON. Le JSON est pour les outils, le CSV pour un tableur —
  et la plupart des gens ouvrent un tableur.
- **Un `README.txt` dans l'archive** : trois lignes décrivant les champs et les unités. C'est ce qui
  transforme un dump en donnée utilisable.
- **Nommage daté** : `livaside-export-2026-10-04.zip`.
- **Schéma versionné** (`"schemaVersion": 1`) pour que les exports restent lisibles après évolution
  du modèle.
- **Réimport du propre export.** Pas en v1, mais c'est la version forte de la promesse : des données
  qu'on peut sortir *et* remettre. À garder en tête dans le choix du schéma maintenant, pour ne pas
  avoir à le refaire.

### 4.3 Peut attendre

Export planifié, export sélectif par période, formats interopérables santé (FHIR, HL7). Aucun
intérêt pour l'usage visé à ce stade.

---

## 5. Ce qu'Apple exigera au moment de la publication

Checklist à reprendre telle quelle au moment de la soumission. Rien ici ne concerne la démo.

### 5.1 Obligatoire — refus garanti si absent

| # | Exigence | Règle |
|---|---|---|
| 1 | URL de politique de confidentialité dans App Store Connect **et** accès dans l'app | 5.1.1(i) |
| 2 | La politique identifie les données, leur collecte, tous leurs usages, la rétention, l'effacement et la révocation du consentement | 5.1.1(i) |
| 3 | App Privacy Details (étiquette de confidentialité) remplies dans App Store Connect | Prérequis de soumission |
| 4 | Purpose string HealthKit explicite | 5.1.1(ii) |
| 5 | Entitlement HealthKit activé sur le profil de provisionnement | Prérequis technique |
| 6 | Aucune donnée de santé dans iCloud | 5.1.3(ii) |
| 7 | Aucune donnée HealthKit utilisée pour la publicité, le marketing ou du « use-based data mining » | 5.1.2(vi), 5.1.3(i) |
| 8 | `PrivacyInfo.xcprivacy` si l'app touche une « required reason API » | Refus automatique App Store Connect (ITMS-91053) depuis le 1er mai 2024 |
| 9 | Une fonctionnalité payante ne doit pas dépendre de l'octroi d'un accès aux données | 5.1.1(ii) : « Paid functionality must not be dependent on or require a user to grant access to this data » |

Sur le point 8 : les catégories concernées sont les API d'horodatage de fichier, de temps de
démarrage système, d'espace disque, de clavier actif et **`UserDefaults`**. Presque toute app touche
`UserDefaults` ; prévoir le fichier avec la raison « accès aux seules données de l'app »
(`CA92.1`). C'est cinq minutes, mais c'est un refus automatique à la soumission, pas un avis de
reviewer — donc à ne pas découvrir le jour J.

### 5.2 Ce que les App Privacy Details doivent dire en v1

Avec le § 2.1.4 respecté, la réponse est **« Data Not Collected »** pour toutes les catégories.
Définition Apple de « collect » : « transmitting data off the device in a way that allows you and/or
your third-party partners to access it » ; et « data that is processed only on device is not
"collected" and does not need to be disclosed ».

C'est un argument commercial autant que juridique : sur la fiche App Store, Livaside affichera
« Aucune donnée collectée » là où ses concurrents affichent « Données liées à vous : santé, forme,
identifiants ». À transmettre à Content & Marketing.

Cette réponse devient fausse dès qu'un SDK d'analytics, un backend ou un MCP hébergé apparaît. Elle
doit être revue à chaque changement d'architecture.

### 5.3 Recommandé avant soumission

- **Notes de revue détaillées** : expliquer au reviewer qu'il n'y a ni compte ni serveur, et comment
  tester (l'app sur un simulateur sans données Santé paraît vide — cause classique de refus pour
  « fonctionnalité insuffisante »). Fournir un jeu de données de démonstration ou une vidéo.
- **Captures d'écran avec des données crédibles**, et aucune donnée d'une personne réelle.
- **Vérifier qu'une fiche sans compte ne déclenche pas la demande de « compte de démonstration »**
  (champ à laisser vide avec une note explicite).

### 5.4 Formulations à tenir — app, fiche App Store et site

Guideline 1.4.1 : les apps « that could be used for diagnosing or treating patients may be reviewed
with greater scrutiny », et doivent « clearly disclose data and methodology to support accuracy
claims relating to health measurements ».

Livaside affiche des données venues de l'app Santé, il n'en mesure aucune — c'est une position
confortable, à condition de ne pas s'en écarter dans le wording :

- **À éviter** : « diagnostic », « détecte », « traite », « améliore votre santé », « qualité du
  sommeil » présenté comme un score médical, « recommandation » sur un ton prescriptif.
- **À privilégier** : « suivi », « tendances », « évolution », « vos données réunies », « ce que vous
  avez enregistré ».
- **Pas de revendication de précision** sur une mesure. Si un chiffre est un calcul de Livaside
  (moyenne, estimation), le dire dans l'écran.
- **Une ligne dans l'app** : « Livaside n'est pas un dispositif médical et ne remplace pas un avis
  professionnel. »

À transmettre à Content & Marketing : cette liste s'applique à la landing page autant qu'à l'app.
Une promesse marketing trop forte sur la santé est un motif de refus de la fiche, même quand l'app
elle-même est sage.

---

## 6. Ce qui rend l'accès MCP défendable

C'est le point le plus sensible du produit, et c'est aussi le différenciateur. Il est défendable,
mais pas sous n'importe quelle architecture. La décision d'architecture (LIV-4) détermine le niveau
de risque — elle doit être prise en connaissance de ces contraintes, pas après.

### 6.1 La règle qui s'applique

Deux clauses, à lire ensemble :

- **5.1.2(i)** : « You must clearly disclose where personal data will be shared with third parties,
  **including with third-party AI**, and obtain explicit permission before doing so. » La mention
  explicite de l'IA tierce est récente et visée.
- **5.1.3(i)** : les données HealthKit ne peuvent être divulguées à des tiers « for advertising,
  marketing, or other use-based data mining purposes **other than improving health management**, or
  for the purpose of health research, and then only with permission ».

Lecture : 5.1.3(i) **n'interdit pas** qu'une donnée de santé quitte l'app. Il interdit la publicité,
le marketing et l'exploitation de données, et réserve explicitement l'usage « improving health
management ». Un utilisateur qui interroge ses propres données avec son propre assistant tombe dans
l'exception, pas dans l'interdiction. Ce qui ferait basculer dans l'interdiction, c'est Livaside qui
exploiterait ce flux pour autre chose que le service rendu à cet utilisateur.

### 6.2 Les cinq conditions

1. **L'utilisateur déclenche, toujours.** Aucun flux automatique, aucune synchronisation de fond,
   aucun accès par défaut. L'accès MCP est désactivé à l'installation et s'active par un geste
   explicite.
2. **Consentement spécifique, distinct de celui de HealthKit.** Un écran qui nomme la chose :
   quelles données seront accessibles, à quel client, et que ce client est un service tiers que
   Livaside ne contrôle pas. Révocable en un geste, au même endroit. 5.1.1(ii) : « Apps must also
   provide the customer with an easily accessible and understandable way to withdraw consent. »
3. **Livaside n'est pas dans la boucle.** Aucune copie, aucun log de contenu, aucune télémétrie des
   requêtes côté Livaside. C'est ce qui permet de dire que Livaside ne partage pas les données :
   l'utilisateur les expose à un destinataire qu'il a choisi. Cette phrase doit rester littéralement
   vraie, sinon toute l'argumentation tombe.
4. **Périmètre lisible et restreint.** L'accès MCP expose un sous-ensemble choisi (ex. agrégats et
   séries temporelles), pas le store brut. Minimisation appliquée au flux sortant, pas seulement à
   la collecte.
5. **Dit dans la politique, pas enfoui.** La politique doit nommer le mécanisme, nommer le fait que
   le destinataire est choisi par l'utilisateur, et préciser que les conditions du service tiers
   s'appliquent alors à ces données. 5.1.1(i) impose en outre de confirmer que tout tiers accédant
   aux données offre une protection équivalente — ce qu'on ne peut **pas** garantir pour un service
   choisi par l'utilisateur. La réponse à cette tension est de ne pas se présenter comme celui qui
   partage : c'est l'utilisateur qui connecte son outil.

### 6.3 Conséquence pour l'architecture (LIV-4)

Deux familles de solutions, très inégales en risque :

- **Serveur MCP local, sur l'appareil ou la machine de l'utilisateur, client apporté par
  l'utilisateur.** Les données ne transitent par aucune infrastructure Livaside. On reste sur
  « Data Not Collected », la politique du § 3.2 reste vraie, et 5.1.3(ii) n'est pas en cause.
  **C'est l'option à privilégier**, et de loin.
- **Serveur MCP hébergé par Livaside.** Change tout : Livaside devient responsable de traitement de
  données de santé (RGPD art. 9), il faut une base légale, de la sécurité démontrable, une
  déclaration App Store « données de santé liées à vous », une politique réécrite, et le risque
  5.1.3(ii) réapparaît si l'hébergement touche iCloud. Faisable, mais c'est un autre produit et un
  autre budget conformité. **Ne pas s'y engager sans avis juridique.**

Cette comparaison est à verser dans LIV-4 comme contrainte d'entrée. Je ne décide pas de
l'architecture ; je dis ce que chaque branche coûte en conformité.

### 6.4 Risque 1.4.1 propre à l'IA

Une IA branchée sur des données de santé produit spontanément des interprétations qui ressemblent à
un avis médical. Ce n'est pas Livaside qui les produit, mais c'est Livaside qui aura mis la donnée à
disposition — et c'est sur sa fiche App Store que la promesse sera lue. Donc : ne jamais présenter
l'accès MCP comme un outil d'analyse ou de conseil santé. Le positionner comme ce qu'il est —
*« vos données, accessibles à l'outil de votre choix »* — pas comme *« un coach IA »*. Le wording
marketing du MCP est un sujet de conformité autant que de marque.

---

## 7. RGPD — où on en est

### 7.1 La v1 telle que décidée

Les données de sommeil, d'activité et de nutrition sont des **données concernant la santé**, donc
une catégorie particulière au sens de l'**art. 9 RGPD**, dont le traitement est interdit par défaut
sauf exception (art. 9.2, notamment le consentement explicite).

Mais : tant que le traitement a lieu **intégralement sur l'appareil** et que l'éditeur n'y a **aucun
accès**, l'éditeur ne traite pas ces données. Il fournit un logiciel. Il n'est pas responsable de
traitement pour le suivi local, et les obligations qui en découlent — registre, information au sens
de l'art. 13, réponse aux demandes d'accès (art. 15) et de portabilité (art. 20), analyse d'impact
(art. 35) — ne lui incombent pas pour cette fonction.

Concrètement, pour la v1 : **rien à produire côté RGPD au-delà des textes du § 3.** Pas de registre
de traitements, pas d'AIPD, pas de DPO, pas de mentions légales complexes. Le choix du 100 % local
n'est pas seulement rapide à construire — c'est l'application littérale de l'**art. 25**
(protection des données dès la conception) et de la minimisation (**art. 5.1.c**). La donnée qu'on
ne collecte pas n'a pas à être protégée, et n'a pas à être documentée.

Référence française utile le moment venu : la **recommandation de la CNIL relative aux applications
mobiles** (adoptée en septembre 2024), qui traite précisément des rôles respectifs de l'éditeur
d'application, du fournisseur d'OS et des SDK tiers.

### 7.2 Ce qui crée malgré tout une obligation aujourd'hui

**La liste d'attente du site (LIV-6).** Une adresse email collectée est une donnée personnelle, et
là Livaside **est** responsable de traitement. C'est la seule obligation RGPD réellement active à ce
stade :

- **Obligatoire** : une mention d'information au point de collecte (qui collecte, pour quoi, combien
  de temps, comment se désinscrire, comment nous contacter) ; une base légale — le consentement, via
  une case non précochée ou un bouton dont la finalité est explicite ; un lien de désinscription
  dans chaque envoi ; et, si un service d'emailing est utilisé, vérifier qu'il agit comme
  sous-traitant au sens de l'**art. 28** (contrat de sous-traitance, et localisation des données).
- **Recommandé** : pas d'autre champ que l'email ; durée de conservation annoncée et tenue ; pas de
  cookie d'analyse, ou un outil sans cookie et sans consentement requis — ce qui évite d'avoir à
  poser un bandeau sur une landing page.
- **Peut attendre** : registre formel des traitements (une page suffira), politique de cookies
  (inutile s'il n'y a pas de cookie).

Texte minimal fourni à Content & Marketing :

> Nous utilisons votre adresse pour vous prévenir du lancement de Livaside, et pour rien d'autre.
> Pas de revente, pas de partage. Un lien de désinscription dans chaque message, et vous pouvez
> demander la suppression de votre adresse à [contact] à tout moment.

### 7.3 Ce qui rouvrirait le dossier

Dans l'ordre de gravité : un MCP hébergé, un backend ou une sync serveur, un compte utilisateur, un
SDK d'analytics, une fonction de partage social. Chacun fait de Livaside un responsable de
traitement de données de santé et déclenche base légale, information, sécurité (art. 32), et très
probablement une **AIPD** (art. 35 : traitement à grande échelle de données de l'art. 9). À
anticiper, pas à craindre — mais à ne jamais introduire en cours de sprint sans me le signaler.

---

## 8. Ce qui nécessite un avis d'avocat

Je ne suis pas un conseil juridique définitif. Trois sujets, et aucun avant la publication :

1. **Avant la première soumission App Store** : relecture de la politique du § 3.2 par un avocat
   spécialisé (données personnelles / santé), et confirmation du raisonnement du § 7.1 — l'absence de
   qualité de responsable de traitement pour le traitement purement local. C'est le fondement de
   toute la position ; il mérite une validation externe, qui devrait être courte et peu coûteuse vu
   la simplicité de l'architecture.
2. **Avant tout MCP hébergé, tout backend ou toute sync** : qualification des rôles, base légale
   art. 9, nécessité d'une AIPD. Ne pas construire avant cet avis.
3. **Avant toute revendication santé dans le marketing** (« améliore votre sommeil », « optimise la
   récupération ») : frontière avec le dispositif médical au sens du règlement (UE) 2017/745. Tant
   que Livaside affiche et n'interprète pas, la question ne se pose pas.

---

## 9. Décisions demandées au CEO

Aucune ne bloque la démo. Toutes doivent être tranchées avant la soumission App Store.

**9.1 — Positionnement médical.** Confirmer que Livaside n'émettra aucune recommandation de santé,
dans l'app comme dans le marketing, et que les règles de wording du § 5.4 s'appliquent à la landing
page. Impact : guideline 1.4.1, et le périmètre de l'avis juridique du § 8.3.

**9.2 — Sauvegarde iCloud du store local.** L'app ne doit pas écrire dans iCloud (§ 2.1.3, règle
ferme). Reste le cas de la sauvegarde système iPhone, qui embarque par défaut le fichier SwiftData.
La règle 5.1.3(ii) vise la synchronisation par l'app, pas la sauvegarde de l'appareil par
l'utilisateur ; l'app Santé d'Apple est elle-même sauvegardée. Mon avis : **laisser la sauvegarde
active et le dire dans la politique** — l'exclure signifierait qu'un utilisateur changeant d'iPhone
perd tout son historique, ce qui contredit la promesse produit pour un gain de conformité
discutable. Décision à acter, et à faire confirmer avec l'avis du § 8.1.

**9.3 — Branche d'architecture MCP.** Le § 6.3 oppose un MCP local (risque faible, politique
inchangée, « Aucune donnée collectée » préservé) à un MCP hébergé (Livaside devient responsable de
traitement de données de santé, avis juridique obligatoire, déclaration App Store modifiée). C'est
un arbitrage de périmètre et de budget, pas un choix technique. À trancher avec le Backend & MCP
Engineer (LIV-4) avant que l'architecture ne soit figée.

**9.4 — Prérequis matériels de la publication**, à prévoir sans urgence : une URL stable pour la
politique, une adresse de contact pour les demandes relatives aux données, et l'entité qui publie
l'app (nom à faire figurer dans la politique).
