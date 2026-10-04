# Livaside — démo MVP iOS

Application iOS 17+ locale destinée à la démo Livaside. Elle ne possède ni réseau, ni backend, ni compte, ni écriture dans Santé. Le projet s'appelle encore `LivasideSpike` pour conserver le provisioning déjà validé : le produit affiché est désormais Livaside.

## Livré dans cette tranche

- **Aujourd’hui** : sommeil de la nuit, séances du jour, dernière pesée (avec sa date) et repas du jour. Chaque donnée absente est affichée comme telle. On supprime un repas en le balayant vers la gauche.
- **Ajouter un repas** : seuls le nom et les calories sont obligatoires, les macros restent facultatives. Le clavier s’ouvre directement sur le nom. La section **Récents** permet de ressaisir un repas habituel en deux touches. L’heure se cale sur l’heure actuelle à chaque ouverture.
- **Tendances** : sommeil et poids sur 7 ou 30 jours. La courbe s’interrompt quand il manque une nuit, ou après une semaine sans pesée. Pour l’activité, l’app affiche le nombre de séances et les minutes actives.
- **Apple Health, import automatique** : une requête ancrée par type lit seulement les ajouts et les suppressions depuis la dernière synchro. Chaque échantillon est conservé localement avec son UUID et sa source (`HealthRecord`). Les agrégats journaliers sont ensuite recalculés. Des observateurs avec livraison en arrière-plan réveillent l’app quand Santé reçoit des données. La première synchro lit 90 jours.
- **Mode démo** (menu `…` de l’écran Aujourd’hui) : 35 jours de données fictives (sommeil, pesées, séances, repas du jour), recréés à l’identique à chaque activation. Ces données vivent dans un stockage séparé, en mémoire : les vraies données ne sont jamais touchées. Pour revenir aux vraies données, désactiver le mode démo.

La durée de sommeil est l’union des intervalles `asleep*`, ce qui évite de compter deux fois des données qui se chevauchent. Une séance est affectée au jour où elle commence. Quand deux sources enregistrent la même séance (recouvrement d’au moins la moitié), elle ne compte qu’une fois et l’app garde la plus longue ; les deux échantillons restent conservés. Le poids et la masse grasse sont moyennés par jour ; la masse grasse est conservée comme fraction (`0,15` = `15 %`). Toutes ces règles sont dans `HealthAggregator.swift`.

## Test sur l’iPhone du fondateur

1. Ouvrir `LivasideSpike.xcodeproj` dans Xcode 16+ et sélectionner l’iPhone physique.
2. Dans **Signing & Capabilities**, sélectionner l’équipe Apple du fondateur. Vérifier la capacité **HealthKit** (avec Background Delivery) et l’identifiant de bundle avant de lancer.
3. Lancer l’app. Si la feuille Santé apparaît, autoriser Sommeil, Séances, Poids et Masse grasse.
4. Attendre « Dernière synchro : … » dans l’onglet Aujourd’hui, puis vérifier la nuit, les séances, le poids et l’onglet Tendances.
5. Ajouter un repas, d’abord en le tapant, puis via **Récents**. Il doit apparaître dans Aujourd’hui et rester après avoir fermé puis rouvert l’app.
6. Import automatique : enregistrer une pesée à la main dans l’app Santé, revenir dans Livaside et tirer pour rafraîchir. La pesée doit apparaître. Supprimer cette pesée dans Santé, puis resynchroniser : elle doit disparaître.
7. Démo : `…` → **Mode démo**. Parcourir Aujourd’hui → Ajouter → Tendances (7 puis 30 jours), puis désactiver le mode démo. Les vraies données doivent être revenues, intactes.

Commande de vérification hors signature, réussie le 4 octobre 2026 :

```sh
xcodebuild -project HealthKitSpike/LivasideSpike.xcodeproj -scheme LivasideSpike \
  -sdk iphoneos -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Captures sur simulateur (build Debug) : `-demoMode YES` active la démo et `-captureTab today|meal|trends` ouvre directement un onglet, par exemple
`xcrun simctl launch <simulateur> com.livaside.healthkitspike -demoMode YES -captureTab trends`.

L’habillage (direction artistique v1, LIV-17) passe par `Theme.swift` (jetons du designer) et `ThemeComponents.swift` (cartes, titres en New York, axes des graphiques).

Les fichiers `HealthKitProbe.swift`, `SpikeView.swift` et `Report.swift` viennent du spike LIV-3. Seuls les helpers d’intervalles de `Report.swift` servent encore à l’app.

---

## Notes du spike HealthKit (référence)

## Ce que le spike lit

- Sommeil : intervalles `inBed`, `awake`, `asleepUnspecified`, `asleepCore`, `asleepDeep` et `asleepREM` ; regroupement en nuits et fusion des recouvrements.
- Séances : type, durée, source, énergie et distance lorsque fournis par la source.
- Mesures : poids, masse grasse, masse maigre et taille.
- Tendances : agrégats journaliers de 7/30 jours pour les quantités disponibles.

La liste des types est centralisée dans `HealthKitProbe.allReadTypes`. Aucun type n'est partagé/écrit : `allWriteTypes` est vide. Le projet déclare uniquement `NSHealthShareUsageDescription` (lecture) ; l'absence volontaire de `NSHealthUpdateUsageDescription` empêche toute demande d'écriture. Les données et les rapports restent dans le conteneur Documents de l'appareil.

## Lancer sur l'iPhone du fondateur

1. Ouvrir `LivasideSpike.xcodeproj` dans Xcode 16+ et sélectionner l'iPhone physique. HealthKit ne fournit pas de données représentatives dans le simulateur.
2. Dans Signing & Capabilities, choisir l'équipe Apple du fondateur et vérifier la capacité **HealthKit**, y compris **Background Delivery** si elle est disponible dans le profil.
3. Installer puis lancer. La demande Santé ne propose que des lectures ; autoriser au moins Sommeil, Séances et Poids.
4. Attendre la fin du diagnostic puis utiliser « Partager le rapport ». Les fichiers `spike-healthkit.md` et `spike-healthkit.json` sont aussi enregistrés dans Documents.

Le rapport indique explicitement les sources, le chevauchement, les nuits sans phases, les jours sans mesures, les suppressions remontées par requête ancrée et l'état de la livraison en arrière-plan.

## Conclusions déjà intégrées au modèle MVP

| Sujet | Décision produit / modèle |
| --- | --- |
| Sommeil | Conserver les échantillons source avec UUID, intervalle, phase et provenance ; calculer une nuit agrégée après fusion d'intervalles. Ne jamais additionner `inBed` et `asleep*`. |
| Phases | Les afficher seulement lorsqu'elles existent. Une nuit sans détail est normale, notamment sans montre. |
| Sources multiples | Garder provenance et UUID. Dédupliquer les séances qui se chevauchent sans supprimer l'original ; agréger le poids par jour à l'affichage. |
| Données supprimées | Import incrémental par `HKAnchoredObjectQuery` et persistance de l'ancre par type ; appliquer aussi les suppressions. |
| Tendance | Un trou est une absence, pas zéro. La moyenne se fonde sur les jours présents et la courbe s'interrompt. |
| Arrière-plan | Afficher « dernière synchronisation ». HealthKit décide du moment réel de livraison : aucune promesse de temps réel. |

## Validation sur appareil réel — 4 octobre 2026

Le spike a été exécuté sur l'iPhone du fondateur (iPhone17,2, iOS 27.0.1) : sommeil, séances, poids et mesures ont été lus depuis plusieurs sources, l'import ancré a été vérifié en deux passages et la livraison en arrière-plan a été accordée. Les lectures restent rapides (9 ms sur 30 jours de sommeil, 92 ms sur 365 jours dans cet essai).

Le MVP peut donc promettre une connexion automatique à Apple Health, avec deux limites non négociables : les phases ne sont pas disponibles chaque nuit et la synchronisation n'est pas en temps réel. L'interface doit afficher la dernière synchro et un état vide utile. Le rapport brut est attaché à LIV-3 dans Paperclip.

Note de lecture : HealthKit retourne la masse grasse en fraction pour `.percent()` ; `0,15` doit être présenté comme `15 %`, pas `0,15 %`.
