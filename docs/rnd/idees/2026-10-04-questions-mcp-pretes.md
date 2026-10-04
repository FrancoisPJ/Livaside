# Idée 3 — Questions prêtes à poser à son IA (onboarding MCP)

**Statut :** proposée · **Date :** 4 octobre 2026 · **Veille :** [../veille-2026-10.md](../veille-2026-10.md)

## 1. Problème
- **Pour qui :** l'utilisateur qui a connecté (ou pourrait connecter) son assistant IA à Livaside mais ne sait pas quoi lui demander.
- **Preuve :** les solutions MCP santé existantes sont des serveurs génériques à 60 ou 190 métriques ([Glama](https://glama.ai/mcp/servers/turnnoblindeye/wellness-project-mcp), [mcpservers.org](https://mcpservers.org/servers/philipad/health-export-mcp) ⚠︎), exposés par l'exemple « compare ma VFC cette semaine ». Notre MCP est justement conçu à sept outils larges. Preuve d'usage manquante : à observer en bêta.

## 2. Hypothèse
Si l'app propose 8 à 10 questions testées (« Pourquoi ai-je mal dormi cette semaine ? », « Mes protéines suivent-elles mes séances ? ») à copier en un tap, alors plus de bêta-testeurs posent une première question à leur IA, mesuré par : ≥ 4 bêta-testeurs sur 5 obtiennent une réponse juste en moins de 2 minutes après connexion, et ≥ 80 % des questions de la liste reçoivent une réponse correcte (vérifiée sur données de démo) en un seul appel d'outil lorsque c'est prévu.

## 3. Lien avec les principes
- **Ouverture / MCP :** c'est le différenciateur, rendu utilisable.
- **Temps gagné :** supprime la page blanche.
- **Vue unifiée :** les questions croisent sommeil, séances et nutrition, ce qu'une app mono-domaine ne peut pas faire.
- **Données à l'utilisateur :** la question est copiée, rien n'est envoyé par Livaside.

## 4. Impact / effort / confiance
- **Impact :** fort pour les utilisateurs MCP, nul pour les autres · **Effort : S** (liste + test sur données de démo ; pas de nouveau code de production lourd) · **Confiance :** moyenne.
- Réversible : si personne n'y touche, on retire.

## 5. Risques données et privacy
Aucune donnée supplémentaire. Les questions ne doivent pas inciter à des conclusions médicales (pas de « diagnostic »). Relecture Privacy du texte, cohérente avec la ligne « jamais un coach IA » de l'[architecture](../../architecture-mcp.md).

## 6. Recommandation
**Go prototype**, en priorité : le moins cher des cinq et le plus lié à notre avantage. Brief : liste de 10 questions, testée avec le MCP local contre les données de démo, avec les réponses attendues.
