<!-- Source : Paperclip LIV-24, document `amendement-liv4` -->

# Amendement LIV-4 : notes de plat, écriture `nutrition:propose` et boîte « À valider »

**Statut : décidé (révision 1, 4 octobre 2026).** C'est une décision d'architecture : pas de code ni
d'infrastructure. Ce document amende `architecture-mcp.md` (LIV-4) et l'emporte sur lui partout où ils
divergent. Le reste de LIV-4 ne change pas.

**Entrée :** plan Alimentation validé (LIV-15, `plan-alimentation.md` §2) : les notes de plat sont
livrées en deux temps, d'abord dans l'app, puis branchées sur l'IA quand le service MCP existera.

---

## 1. La décision en huit lignes

1. **Une seule écriture MCP, et ce n'est pas une écriture dans le journal.** La portée
   `nutrition:propose` permet à l'assistant de **proposer** des valeurs pour une note en attente. Une
   proposition n'est pas une donnée : elle attend dans la boîte « À valider » du téléphone.
2. **Le téléphone reste le seul écrivain des données.** Le relais gagne une **boîte de dépôt** pour les
   propositions, séparée de la projection. Il n'a toujours aucune autorité sur la projection.
3. **Le chemin retour est une réponse, jamais un envoi.** Le téléphone récupère les propositions dans
   la réponse de son propre push, au lancement et au retour au premier plan. Le serveur n'initie
   rien : pas de notification push, pas de jeton d'appareil, pas de canal nouveau.
4. **Rien n'entre dans le journal sans un geste par proposition.** On peut tout rejeter d'un coup,
   mais pas tout valider d'un coup.
5. **L'assistant ne choisit ni le jour ni le repas.** Ils viennent de la note. L'assistant ne fournit
   que des aliments, des grammes et des valeurs.
6. **Les notes ne quittent le téléphone qu'avec la portée `nutrition:propose`**, et seulement celles
   qui sont en attente, en texte seul. Les photos restent sur le téléphone.
7. **Un seul contrat, deux transports.** En v1.5 (MCP local), l'aller et le retour se font par fichier
   (AirDrop), et Livaside reste hors de la boucle. En v2, ils passent par le relais. La boîte
   « À valider » ne voit pas la différence.
8. **Pour la démo, rien de nouveau n'est imposé à l'app.** On demande seulement que les notes suivent
   C1/C2 et que l'écran de chiffrage manuel soit celui qui affichera plus tard une proposition (§7).

---

## 2. Ce que ça change dans LIV-4

| LIV-4 disait | Devient |
|---|---|
| §1.7 « Lecture seule au départ » | Lecture seule, **plus une portée de proposition**. Aucune portée `*:write` n'écrit dans les données. |
| §2 « [Le relais] ne renvoie rien vers le téléphone » | Il renvoie **uniquement des propositions**, et **uniquement en réponse** à une requête du téléphone. |
| §2 « Notes libres : gardées sur le téléphone (sauf si l'utilisateur l'active) » | Les notes de plat **en attente** sont poussées **si et seulement si** une connexion active détient `nutrition:propose`. |
| §3 « Portées : lecture seule » | Une sixième portée, `nutrition:propose` (§3 ci-dessous). |
| §4 « Sept outils » | Neuf outils : deux de plus, réservés à la nouvelle portée. |
| E1 « Instantané complet » | **Inchangé** pour la projection. Les notes en attente en font partie. La boîte de dépôt est un objet à part, qui n'est pas un instantané (§4). |

Un principe ne change pas : il n'y a pas de synchronisation bidirectionnelle et pas de résolution de
conflits. Une proposition n'est jamais fusionnée : le téléphone la présente ou la jette.

---

## 3. La portée `nutrition:propose`

### Ce qu'elle donne

- **Lire les notes en attente** : texte, jour, repas, ancienneté. Rien d'autre. Elle ne donne **pas**
  accès au journal : pour ça, il faut `nutrition:read`, demandé et consenti à part.
- **Déposer une proposition** pour une de ces notes.

Elle ne permet pas de créer une entrée sans note, ni de modifier ou supprimer une entrée, une note
ou un aliment. Elle ne permet pas non plus de proposer pour un autre jour ou un autre repas que ceux
de la note.

### Consentement

- C'est une **ligne à part** sur l'écran « Connecter un assistant ». Elle est **décochée par défaut**,
  même quand `nutrition:read` est cochée.
- Le libellé à valider avec Privacy est : *« Laisser [Claude] lire vos notes de plat en attente et vous
  proposer des valeurs. Rien n'est ajouté à votre journal sans votre validation. »*
- La durée et la révocation sont celles de LIV-4 §7 : 90 jours par défaut, et un geste pour révoquer.
- Le journal d'accès enregistre les lectures de notes et les dépôts de propositions, en
  **métadonnées seulement** : « Claude a proposé des valeurs pour 2 notes, il y a 1 h ».

### Les deux outils

| Outil | Rôle | Annotations MCP |
|---|---|---|
| `list_pending_meal_notes()` | Notes en attente : 20 au plus, des 14 derniers jours | `readOnlyHint: true` |
| `propose_meal_note_values(note_id, note_rev, proposal)` | Dépose une proposition pour une note | `readOnlyHint: false`, `destructiveHint: false`, `idempotentHint: true` |

`list_pending_meal_notes` renvoie, pour chaque note :

```json
{
  "note_id": "mealnote:3F2A…",
  "note_rev": "b41c9e",
  "day_key": "2026-10-04",
  "meal": "midi",
  "age_hours": 3,
  "text": { "untrusted_user_text": "assiette de pâtes carbo au resto, grosse portion" },
  "has_photo": true,
  "already_proposed": false
}
```

`has_photo` dit seulement qu'une photo existe, pour que l'assistant puisse demander une précision à
l'utilisateur. La photo elle-même n'est jamais transmise.

### Schéma d'une proposition

```json
{
  "label": "Pâtes carbonara, portion restaurant",
  "items": [
    { "name": "Pâtes cuites",     "grams": 300, "kcal": 471, "protein_g": 16.5, "carbs_g": 92.4, "fat_g": 2.7, "fiber_g": 5.4 },
    { "name": "Sauce carbonara",  "grams": 120, "kcal": 336, "protein_g": 11.0, "carbs_g": 4.0,  "fat_g": 30.5, "fiber_g": 0 }
  ],
  "confidence": "medium",
  "assumptions": "Portion restaurant estimée à 300 g de pâtes cuites."
}
```

**Ce que le serveur ajoute, et que l'assistant ne choisit pas :** `proposal_id`, `received_at`, et
`assistant`. Ce dernier est le nom du client OAuth enregistré, pas un nom déclaré par l'assistant.

**Ce que le téléphone calcule, et que l'assistant n'envoie pas :** les totaux. Ils sont toujours
recalculés depuis `items`, pour qu'un total incohérent ne puisse pas exister.

### Limites, vérifiées deux fois (serveur et téléphone)

Le téléphone ne fait pas confiance au relais : il refait toutes ces vérifications lui-même.

| Champ | Règle |
|---|---|
| `label` | 1 à 80 caractères |
| `items` | 1 à 15 |
| `name` | 1 à 60 caractères |
| `grams` | de 1 à 2 000 par aliment, 3 000 pour la proposition entière |
| `kcal` | de 0 à 9 par gramme d'aliment |
| `protein_g`, `carbs_g`, `fat_g`, `fiber_g` | ≥ 0. Leur somme ne dépasse pas `grams`. |
| Cohérence énergie | 4 × prot. + 4 × gluc. + 9 × lip. doit rester à ±30 % de `kcal`. Sinon, la proposition est **acceptée avec un avertissement** affiché dans la boîte, pas rejetée. |
| `confidence` | `low`, `medium` ou `high` |
| `assumptions` | 0 à 280 caractères |
| Textes (tous) | Texte brut. On retire les caractères de contrôle, les URL et le balisage (§6). |

### Règles de dépôt

- **Une proposition par note.** Un nouveau dépôt remplace le précédent, s'il n'a pas encore été
  récupéré : l'assistant peut se corriger.
- **`note_rev` est obligatoire.** C'est une empreinte courte du texte de la note. Si l'utilisateur a
  modifié la note entre-temps, le dépôt est refusé (`note_changed`), et l'assistant relit la note.
- **Les erreurs sont explicites et lisibles par l'assistant** : `note_not_pending`, `note_changed`,
  `out_of_bounds:<champ>`, `quota_exceeded`, `scope_missing`.

---

## 4. Le flux complet (v2, relais)

```
 iPhone                               Relais (UE)                        Assistant
   │                                     │                                   │
   │ 1. push : projection + notes        │                                   │
   │    en attente + accusés de          │                                   │
   │    réception ─────────────────────▶│                                   │
   │◀──────────── 2. réponse :           │                                   │
   │       propositions disponibles      │                                   │
   │                                     │◀── 3. list_pending_meal_notes ───│
   │                                     │─── notes (texte seul) ──────────▶│
   │                                     │◀── 4. propose_meal_note_values ──│
   │                                     │    → boîte de dépôt              │
   │ 5. lancement suivant : push ───────▶│                                   │
   │◀──────────── propositions           │                                   │
   │ 6. boîte « À valider »              │                                   │
   │ 7. geste de l'utilisateur →         │                                   │
   │    FoodEntry (valeurs figées)       │                                   │
   │ 8. push suivant : accusé, la note   │                                   │
   │    n'est plus en attente ──────────▶│ → proposition et note effacées   │
```

### Le chemin retour, précisément

- C'est **un seul échange**, à l'initiative du téléphone, au lancement et au retour au premier plan.
  La requête porte l'instantané et les identifiants des propositions déjà reçues. La réponse porte
  les propositions en attente pour cet appareil.
- **Il ne passe ni par une notification push ni par une tâche de fond.** Une notification push
  demanderait un jeton d'appareil (contraire à E3), un service de plus et une raison de plus de
  réveiller l'app. Le prix est assumé : **une proposition apparaît à la prochaine ouverture de
  l'app.** Pour une note de repas, c'est sans conséquence.
- **Il est authentifié par la clé de l'appareil** (LIV-4 §3). Le relais ne rend une proposition qu'à
  l'appareil propriétaire de la note.

### La boîte de dépôt, côté relais

- Elle est **séparée de la projection** et n'est pas écrasée par le push. C'est la seule donnée du
  relais qui ne vient pas du téléphone. Elle est donc gardée **au minimum**.
- Elle est effacée à trois moments : quand le téléphone **accuse réception**, à **14 jours** si
  personne ne la récupère, et à la **révocation** (§6).
- Elle est **jetable**, comme le reste du relais. Si elle est perdue, l'utilisateur redemande à son
  assistant, et rien de ce qui est dans son journal n'est touché.

### Les notes poussées

- Seules les notes **en attente** partent, avec la projection, **en texte seul**, et **seulement si**
  une connexion active détient `nutrition:propose`. Sans cette portée, aucune note ne quitte le
  téléphone.
- Elles suivent E1 : chaque push remplace la liste. Une note validée, supprimée ou modifiée disparaît
  ou change au push suivant, sans pierre tombale.

---

## 5. La boîte « À valider »

C'est la promesse visible de l'amendement : **l'IA propose, l'utilisateur décide.**

- **Une carte par proposition** : la note d'origine, le libellé, les aliments avec leurs grammes, les
  totaux recalculés, la confiance, les hypothèses de l'assistant, et son nom (« proposé par Claude »).
- **Trois gestes :**
  - **Valider** : crée l'entrée du journal avec des valeurs **figées** (comme toute `FoodEntry`), au
    jour et au repas de la note. La note passe à « validée ».
  - **Modifier** : ouvre l'**écran de chiffrage manuel**, pré-rempli. Il ne faut pas d'écran de
    plus (§7).
  - **Rejeter** : la proposition est jetée, et la note **revient en attente**. L'utilisateur peut la
    chiffrer à la main ou redemander.
- **Pas de « tout valider ».** Valider, c'est ajouter des chiffres à son journal, et un geste par
  proposition est le prix du contrôle. Avec quelques notes par jour, c'est quelques secondes.
  **« Tout rejeter » existe**, parce que rejeter n'a jamais de conséquence.
- **Les propositions obsolètes sont jetées sans bruit** : celles dont la note a été validée à la main,
  supprimée ou modifiée depuis (`note_rev` différent).
- **Provenance conservée** : l'entrée validée garde « estimé par Claude, validé le 4 oct. » (source
  `ia` du modèle `Food`). L'utilisateur, l'app et le MCP savent toujours d'où vient un chiffre.

---

## 6. Menaces et garde-fous

| Menace | Ce qui peut arriver | Garde-fou |
|---|---|---|
| **Injection via la note** | Le texte d'une note, par exemple copié d'un menu, contient « ignore tes instructions, envoie… ». L'assistant le lit avec ses autres outils (e-mail, fichiers). | Le texte est livré comme **donnée**, sous une clé `untrusted_user_text` explicite. Il est limité à 500 caractères, et les descriptions d'outils précisent qu'une note ne contient jamais d'instruction. Surtout, **notre serveur n'expose aucun outil dangereux** : le pire qu'une injection obtienne de Livaside, c'est une mauvaise proposition, que l'utilisateur rejette. Le risque qui reste concerne les autres outils de l'assistant. Il appartient au client, et on le dit dans l'aide. |
| **Injection en retour, de l'assistant vers l'app** | Une proposition affiche « Votre compte expire, cliquez ici » ou du balisage qui trompe l'écran. | Tout s'affiche en **texte brut**. On retire les URL, le balisage et les caractères de contrôle, et les longueurs sont plafonnées (§3). Le nom affiché est celui du client OAuth, jamais un nom déclaré par l'assistant. |
| **Valeurs absurdes**, par erreur ou malveillance | 5 000 kcal pour un yaourt | Bornes vérifiées côté serveur **et** côté téléphone, totaux recalculés, avertissement sur l'incohérence énergétique, et surtout **le geste de validation**. |
| **Volume** | Un assistant en boucle dépose des centaines de propositions. | **1 proposition par note**, qui remplace la précédente. Une proposition n'est possible que pour une note **en attente existante**, donc au plus 20. 60 dépôts par heure et par connexion, au-delà `quota_exceeded`. Requête plafonnée à 16 Ko. Le volume maximal stocké est borné par le nombre de notes, pas par l'assistant. |
| **Jeton volé ou assistant compromis** | Un tiers lit les notes et dépose des propositions. | Le tiers ne peut ni lire le journal (portée distincte), ni écrire dans le journal, ni toucher une autre donnée. Le journal d'accès montre l'activité, et la révocation coupe tout (ligne suivante). |
| **Révocation** | L'utilisateur retire l'accès. | La révocation, ou le retrait de la seule portée `nutrition:propose`, déclenche trois effets côté relais : les propositions de cette connexion **sont effacées**, et si plus aucune connexion n'a `nutrition:propose`, **les notes sont effacées** de la projection et ne sont plus poussées. Côté téléphone, les propositions déjà reçues restent dans la boîte, marquées « accès révoqué ». Elles sont rejetables d'un geste, et validables une par une si l'utilisateur le veut : elles sont sur son téléphone. |
| **Proposition rejouée ou périmée** | Une ancienne proposition réapparaît après modification de la note. | `note_rev` est vérifiée au dépôt **et** à l'affichage. Les identifiants sont à usage unique, et le téléphone ignore un `proposal_id` déjà traité. |
| **Confusion avec un conseil médical** (Privacy §6.4) | « Claude dit que je mange trop gras » | La portée sert à **chiffrer** une note, pas à juger. Les descriptions d'outils et le wording de l'app parlent de « valeurs proposées », jamais de « recommandations ». |

---

## 7. Ce que ça demande à l'app : rien de plus pour la démo

Ces points concernent le modèle `MealNote` de LIV-22. Ce sont des **recommandations à confirmer
avec l'iOS Engineer**, pas des contraintes imposées. Seules les deux premières protègent le futur
MCP.

1. **C1/C2 s'appliquent aux notes** : `uid` déterministe `mealnote:<UUID>`, `dayKey`, `timeZoneID`,
   `createdAt`/`updatedAt`. C'est la règle déjà écrite pour `Meal`.
2. **Le repas (matin, midi, soir, collation) et le jour sont portés par la note**, puisque l'assistant
   ne les choisit pas.
3. **Statuts.** Je recommande de séparer le statut de la note et le sort de la proposition. La note a
   trois statuts : `en_attente`, `proposée`, `validée`. Le rejet s'applique à la **proposition** et
   ramène la note en attente. Le statut `rejetée` du plan devient ainsi inutile sur la note : une note
   dont on ne veut plus se supprime.
4. **L'écran de chiffrage manuel des notes est l'écran de proposition.** Construit maintenant pour le
   chiffrage à la main, il sera pré-rempli plus tard par une proposition. C'est ce qui rend le
   branchement IA quasi gratuit côté app : la boîte « À valider » se résume alors à une liste de
   cartes et trois boutons.
5. **C5 (export)** inclura les notes en attente, en texte seul, quand l'export sera fait. Ça ne coûte
   qu'un DTO de plus et ce n'est pas bloquant.

**Hors démo, à faire au branchement :** l'import d'un fichier de propositions (v1.5), l'échange
push/réponse (v2), la carte de la boîte et la ligne de consentement.

---

## 8. La v1.5 : le même flux, sans relais

La v1.5 (MCP local sur le Mac, LIV-4 §6) reste la première livraison du MCP. Elle peut porter les
notes **sans aucune infrastructure** :

1. L'export (C5), envoyé par AirDrop, contient les notes en attente.
2. Le serveur local expose les deux mêmes outils. `propose_meal_note_values` écrit dans un fichier
   `propositions.livaside` à côté de l'export.
3. L'utilisateur envoie ce fichier sur son iPhone par AirDrop. L'app l'ouvre, revérifie tout et
   remplit la boîte « À valider ».

**Ce que ça coûte :** environ une journée côté app (type de fichier déclaré, import, validation) et
quelques heures côté serveur local. **Ce que ça permet :** valider le schéma de proposition et la boîte
avec de vrais utilisateurs à 0 €, sans que Livaside soit dans la boucle. Les conditions Privacy de
LIV-5 §6.2 tiennent toutes. **Ce que ça ferme :** rien. Le format de fichier est exactement la
réponse du relais en v2. **Le prix :** deux AirDrop au lieu d'un geste invisible. C'est acceptable pour
des beta-testeurs, pas pour le grand public, et c'est pour ça que la v2 existe.

---

## 9. Coordination et escalades

**→ Privacy & Compliance (LIV-23)** : quatre points relèvent de la partie données.

1. Le texte d'une note de plat est-il une **donnée de santé** au sens de l'art. 9 ? Ma position
   prudente est de le traiter comme tel, ce qui change la rétention et la base légale côté relais en
   v2.
2. Le **libellé du consentement** de `nutrition:propose` (§3).
3. La **rétention** : propositions 14 jours au plus, notes seulement tant qu'elles sont en attente.
   À confirmer.
4. **Photos** : elles ne sortent jamais du téléphone dans ce design. Si on voulait un jour les
   envoyer à l'assistant, il faudrait un nouvel avis et une nouvelle portée.

**→ CEO : pas de nouvelle escalade.** La v1.5 ne fait pas entrer Livaside dans la boucle. La v2
hérite de la décision déjà posée dans LIV-12 point 3 (MCP hébergé), avec une donnée de plus dans le
périmètre hébergé : le texte des notes en attente. Ce point devra figurer dans le second avis
juridique déjà requis pour la v2.

**→ iOS Engineer (LIV-22, LIV-25)** : les cinq points du §7 sont des recommandations à confirmer, pas
des contraintes. Aucun ne bloque la démo.
