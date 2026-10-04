# Livaside

Vivre pleinement, sans que votre santé vous prenne votre temps.

Livaside réunit sommeil, sport et nutrition dans une seule app iOS, connectée à Apple Health, avec des graphiques clairs et un accès MCP pour interroger ses données avec l'IA de son choix.

## Contenu du dépôt

| Dossier | Contenu |
|---|---|
| `HealthKitSpike/` | App iOS de démo (SwiftUI, iOS 17+, SwiftData local) : écrans Aujourd'hui, Ajouter un repas, Tendances, synchro Apple Health. Voir `HealthKitSpike/README.md`. |
| `landing/` | Landing page, liste d'attente et page confidentialité (HTML statique). |
| `appstore/` | Captures App Store, clair et sombre. |
| `docs/` | Plan MVP, spec, architecture MCP, privacy, design et contenus, exportés depuis Paperclip. |

## Lancer la démo

1. Ouvrir `HealthKitSpike/LivasideSpike.xcodeproj` dans Xcode.
2. Choisir son équipe dans Signing & Capabilities.
3. Lancer sur iPhone, autoriser Santé.
