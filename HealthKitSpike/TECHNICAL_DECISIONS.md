# Décisions techniques — MVP Livaside

_Référence de mise en œuvre pour LIV-8. Dernière mise à jour : 4 octobre 2026, après le spike LIV-3 exécuté sur iPhone (iOS 27.0.1)._

## Périmètre démo

- iOS 17+, SwiftUI et SwiftData, stockage exclusivement local.
- Lecture Apple Health : sommeil, séances, poids et mesures prévues.
- Saisie des repas manuelle ; aucun backend, compte, MCP ou synchronisation multi-appareils dans la démo.

## Règles de données à conserver dans l'app

| Sujet | Décision | Conséquence d'implémentation |
| --- | --- | --- |
| Synchronisation future | L'export MCP utilisera un **instantané complet** de toutes les entités, y compris `Meal`. | Ne pas construire de mécanisme différentiel dédié aux repas. `updatedAt` peut rester une métadonnée locale, mais ne conditionne pas l'export MCP. |
| Sommeil | La durée est l'**union des intervalles** de sommeil qui se recouvrent. | Conserver les échantillons avec UUID, dates, phase et source ; fusionner les intervalles avant tout cumul. Ne jamais additionner les intervalles `inBed` et `asleep*`. |
| Nuits de sommeil | Le détail des phases est facultatif ; une nuit sans montre portée reste une nuit valide. | Regrouper les fragments séparés par plus de 3 h ; afficher « détail indisponible » plutôt qu'une phase inventée. |
| Autorisation Santé | La permission de lecture ne peut pas être déduite de `authorizationStatus(for:)`. | Utiliser `statusForAuthorizationRequest` uniquement pour décider d'ouvrir la feuille ; après la demande, gérer un résultat vide comme « aucune donnée ou accès à vérifier ». |
| Poids et composition | Les échantillons restent la source de vérité, même quand plusieurs sources écrivent le même jour. | Persister UUID, date, valeur, unité et provenance ; calculer la moyenne journalière pour la courbe. La masse grasse est une fraction canonique (`0,15` = `15 %`). |
| Séances | Une séance peut ne pas avoir de distance ni d'énergie, et deux sources peuvent recouvrir le même créneau. | Conserver source et UUID ; utiliser `statistics(for:)` pour énergie/distance ; dédoublonner seulement pour les agrégats avec une règle de priorité explicite, sans effacer l'original. |
| Import HealthKit | L'import doit être incrémental et réversible. | Une ancre persistée par type, traitement des suppressions reçues et miroir SwiftData mis à jour par UUID. |
| Séance à cheval sur minuit | La clé de jour (`dayKey`) est la date de **début** de la séance dans le fuseau de l'utilisateur. | Une séance ne contribue qu'à ce jour dans Aujourd'hui et Tendances. |
| Charge d'entraînement | `training_load` vaut `null` en v1. | Exposer plutôt les minutes actives et le nombre de séances sur 7 et 28 jours ; ne pas inventer de score de charge. |
| Export v1.5 | Sortie uniquement via la feuille de partage système. | Ne pas écrire de fichier dans iCloud depuis l'app. |

## Règles d'affichage et de fiabilité

- Une donnée absente est affichée comme absente, jamais comme zéro ; les courbes s'interrompent.
- Conserver la provenance HealthKit et l'UUID des échantillons. Les doublons potentiels sont signalés/agrégés sans supprimer la donnée source.
- La dernière synchronisation est visible. HealthKit ne garantit pas une livraison en temps réel.
- La disponibilité des données de lecture ne se déduit pas de `authorizationStatus(for:)` : l'état utilisateur se déduit d'une requête et de son résultat.
- Les graphiques ne transforment jamais un trou de données en zéro ; les moyennes se font sur les jours réellement présents.

## État de réalisation LIV-8 — 4 octobre 2026

- Les trois écrans sont implémentés et compilent pour iOS 17, sans avertissement.
- **L’import ancré est fait.** Chaque type a son `HKAnchoredObjectQueryDescriptor`, son ancre persistée (`HealthAnchor`), un miroir par UUID (`HealthRecord`) et l’application des suppressions. Des `HKObserverQuery` et la livraison en arrière-plan sont activés dès le lancement. La fenêtre de lecture est de 90 jours.
- Les agrégats (`DailyHealthSnapshot`) sont recalculés depuis `HealthRecord` par `HealthAggregator`, une fonction pure. Elle a été testée sur macOS : union du sommeil, `inBed` ignoré, doublon multi-source compté une fois, séance après minuit, absence ≠ zéro.
- Le mode démo utilise un stockage en mémoire séparé. Sa génération est déterministe et passe par le même `HealthAggregator`.
- **Pour l’export MCP**, `HealthRecord` (UUID, intervalle, valeur, phase, type de séance, énergie, distance, source) et `Meal` suffisent à produire l’instantané complet prévu. Aucun changement de modèle n’est attendu.
- **Reste à valider sur l’iPhone** : la migration du stockage existant (deux entités ajoutées, migration légère), la première synchro de 90 jours, puis le parcours de démo complet. Aucun simulateur n’était disponible pour l’exécuter ici.

## Reprise par l’iOS Engineer — 4 octobre 2026

- **Stockage jamais dans iCloud** : `LivasideStore.localConfiguration` fixe `cloudKitDatabase: .none` (exigence LIV-5, guideline 5.1.3(ii)). Le target n’a aucun entitlement iCloud.
- **Pas de plantage au lancement si la migration échoue** : un stockage illisible est renommé `default.store.unreadable-<horodatage>` (mis de côté, pas supprimé) et l’app repart d’un stockage neuf. Santé se réimporte ; les repas restent récupérables dans la copie.
- **Identifiant HealthKit, source et UTC (demande MCP)** : déjà satisfaits. `HealthRecord` garde `uuid`, `sourceName`, `sourceBundleId`. Un `Date` SwiftData est un instant absolu, sans fuseau : la conversion en UTC/ISO 8601 avec décalage se fait à l’export. Seul `dayKey` est local, par décision (jour de l’utilisateur).
- **Avant toute publication, hors démo** (LIV-5) : saisie manuelle du poids et des séances sans permission Santé, bouton « Effacer toutes mes données », export JSON via la feuille de partage.
