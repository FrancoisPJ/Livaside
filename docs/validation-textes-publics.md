<!-- Source : Paperclip LIV-10, document `validation-textes-publics` -->

# Textes publics de la landing page — validation conformité

Réponse à LIV-10. Les textes ci-dessous sont **prêts à coller**. Deux placeholders seulement,
entre crochets, à remplir avec deux réponses du fondateur (§6).

---

## Verdict en cinq lignes

| Texte | Verdict |
|---|---|
| 1. Mention sous le formulaire | **À remplacer.** Il manque le responsable, la durée de conservation, les droits et le lien. Version prête en §1. |
| 2. Bloc « Vos données vous appartiennent » | **À corriger.** Une phrase sera fausse le jour où l'accès MCP existera. Version prête en §2. |
| 3. Page de confidentialité | **Oui, obligatoire** — et pas seulement pour le RGPD. Texte intégral en §3. |
| Tally vs Formspree | **Tally.** Formspree n'est pas interdit, mais vous coûte un document à écrire pour un service identique. §5. |
| Bandeau cookies | **Confirmé : aucun.** Pas de tracker, pas de cookie, rien à afficher. |

**Ce qui bloque la publication** (pas la démo) : les trois textes ci-dessous, le lien en pied de
page, et les deux réponses du §6.
**Recommandé mais pas bloquant** : double opt-in (§1), nommer le sous-traitant dans la page.
**Peut attendre** : registre des traitements, fiche App Store, déclaration App Privacy.

---

## 1. Mention sous le formulaire de liste d'attente

### Pourquoi la version actuelle ne suffit pas

Collecter une adresse e-mail est un traitement de données personnelles. L'article 13 du RGPD
impose d'informer la personne **au moment de la collecte**. La CNIL et le CEPD admettent une
**information en deux niveaux** : une mention courte à côté du champ (qui collecte, pour quoi,
et un lien), le reste dans une page accessible en un clic. C'est ce qui permet de rester bref.

La version actuelle dit la finalité, ce qui est déjà bien — mais il manque quatre choses :
qui est responsable, combien de temps l'adresse est gardée, les droits de la personne, et le lien
vers l'information complète. Et une phrase est inexacte : « n'est transmise à personne » sera
faux dès qu'un prestataire de formulaire héberge les adresses.

### Version à coller — recommandée

> Un e-mail quand la première version est prête, rien d'autre. Votre adresse ne sert qu'à ça,
> elle n'est ni revendue ni utilisée ailleurs, et elle est supprimée après cet e-mail.
> Désinscription en un clic. Responsable : [NOM] · [contact@livaside.app] ·
> [Mentions légales et confidentialité](confidentialite.html)

### Version minimale, si la place manque vraiment

> Un e-mail à la sortie, rien d'autre. Votre adresse ne sert qu'à ça et elle est ensuite
> supprimée. [Comment vos données sont traitées](confidentialite.html)

La version minimale est conforme **à condition** que le lien soit visible sans scroller et que la
page du §3 soit en ligne. Elle est moins rassurante à lire : je recommande la première.

### Où chaque exigence de l'article 13 est satisfaite

| Exigence (art. 13 RGPD) | Dans la mention courte | Dans la page §3 |
|---|---|---|
| Identité et contact du responsable | ✅ nom + e-mail | ✅ |
| Finalité | ✅ « un e-mail à la sortie » | ✅ |
| Base légale (consentement, art. 6.1.a) | — | ✅ |
| Destinataires (le prestataire du formulaire) | — | ✅ nommé |
| Durée de conservation | ✅ « supprimée après cet e-mail » | ✅ datée |
| Droits + retrait du consentement | ✅ « désinscription en un clic » | ✅ liste complète |
| Réclamation auprès de la CNIL | — | ✅ avec lien |
| Transferts hors UE | — | ✅ (aucun, avec Tally) |

### Trois points de mise en œuvre

1. **Pas de case à cocher nécessaire.** Le formulaire a une finalité unique et explicite :
   saisir son adresse et cliquer « Être prévenu » **est** le consentement. Ajouter une case
   n'apporte rien et coûte des inscrits. En revanche la mention doit être visible **en même temps
   que le bouton**, pas repliée ni masquée — c'est la condition pour que le consentement soit
   éclairé.
2. **Le second formulaire n'a aucune mention.** `index.html:286-293` (section « Vous voulez suivre
   la suite ? ») ne porte ni mention ni lien. Il faut y mettre la même mention, ou au minimum la
   version minimale ci-dessus. Deux formulaires = deux points de collecte, l'information est due
   aux deux.
3. **Double opt-in : recommandé, pas obligatoire.** Un e-mail de confirmation avant d'inscrire
   l'adresse protège contre les fautes de frappe et les adresses de tiers, et vous donne la preuve
   du consentement. Si Tally le fait en une case à cocher dans son interface, prenez-le. Sinon,
   ne retardez rien pour ça.

### Un engagement à tenir

« Elle est supprimée après cet e-mail » est une promesse publique. Concrètement : après l'envoi de
l'e-mail de sortie, supprimer le formulaire et ses réponses chez le prestataire. Si ce n'est pas
fait, la phrase devient fausse. Si vous préférez ne pas vous engager là-dessus, remplacez par
« conservée le temps de vous prévenir, puis supprimée » et la page du §3 porte la durée chiffrée.

---

## 2. Bloc « Vos données vous appartiennent »

### Ce qui est dicible tel quel, et ce qui ne l'est pas

Sur le fond, oui : SwiftData 100 % local, pas de backend, pas de compte — la promesse est vraie et
vous pouvez la dire fort. Trois corrections de formulation, dont une qui compte vraiment.

**1. « Il n'y a personne à qui les envoyer » — à retirer. C'est le point important.**
La page annonce déjà, au futur, l'accès de votre assistant IA à vos données (section 4). Le jour
où le service MCP existe, les données de santé sortiront de l'iPhone vers l'assistant choisi par
l'utilisateur. La phrase sera alors fausse, sur une page archivée et citable. Deux conséquences :
une promesse publique contredite par le produit relève de la pratique commerciale trompeuse
(art. L121-2 du code de la consommation), et cela crée une divergence avec la future politique de
confidentialité de l'app et la déclaration App Privacy. Le corriger maintenant ne coûte rien et
rend l'argument **plus** fort, pas moins : c'est l'utilisateur qui ouvre la porte.

**2. « Pas de serveur » — à préciser.** Dit sur une page dont le formulaire envoie une adresse
e-mail à un prestataire, c'est ambigu. Il faut rattacher la phrase à l'app : pas de serveur
**pour vos données de santé**.

**3. Le temps présent.** La page s'astreint partout au futur pour ce qui n'existe pas encore
(« rendra », « pourrez »). Le bloc données est au présent (« restent »). Je l'aligne sans alourdir.

### Version à coller

> **Vos données vous appartiennent**
>
> Pas de compte à créer : Livaside fonctionne sans inscription. Vos données de santé sont
> enregistrées sur votre iPhone, pas sur nos serveurs — nous n'en avons pas. Nous ne les vendons
> pas et nous ne les transmettons à personne. Le jour où vous brancherez votre assistant IA, c'est
> vous qui déciderez de lui donner accès, et vous pourrez le retirer quand vous voulez.

### Ce qu'il ne faut pas écrire

- **« Ne quittent jamais votre iPhone ».** Faux dès que l'utilisateur a activé la sauvegarde
  iCloud de son téléphone : les données de l'app sont alors copiées chez Apple. C'est son choix et
  c'est sans danger, mais l'absolu est indéfendable. « Sont enregistrées sur votre iPhone » est
  juste et aussi rassurant.
- **« Chiffrées » / « sécurisées »** sans précision. N'ajoutez pas de qualificatif technique que
  le code ne garantit pas explicitement.
- **La phrase sur l'export**, tant que l'export n'est pas développé. L'export fait partie des
  principes de Livaside et il doit arriver, mais il n'est pas dans le périmètre MVP. Ne le
  promettez sur la page que si l'iOS Engineer confirme qu'il est dans la v1 ; sinon il entre dans
  la politique de confidentialité de l'app au moment de la publication.

---

## 3. Faut-il une page de confidentialité dès la landing ?

**Oui. Et vous en avez de toute façon besoin pour une autre raison.**

Deux fondements, pas un :

1. **RGPD, art. 12 et 13.** L'information en deux niveaux du §1 n'est conforme **que si** le
   second niveau existe et est accessible en un clic. Sans page, la mention courte ne suffit pas.
2. **Identification de l'éditeur du site.** Tout éditeur d'un service de communication au public
   en ligne, professionnel ou non, doit tenir ses éléments d'identification à la disposition du
   public — article 1-1 de la LCEN (ce qui était l'article 6 III avant la loi SREN du 21 mai
   2024). Un éditeur **non professionnel** peut, pour préserver son anonymat, ne publier que le
   nom et l'adresse de son hébergeur, à condition de lui avoir communiqué son identité. C'est
   utile si vous publiez en votre nom propre et ne voulez pas afficher votre adresse personnelle.

**Donc : une seule page, deux sections, un seul lien en pied de page.** Ça évite deux pages à
maintenir. Texte intégral ci-dessous — rien à rédiger.

### Texte intégral — `confidentialite.html`

> # Mentions légales et confidentialité
>
> *Dernière mise à jour : [DATE DE MISE EN LIGNE]*
>
> ## Qui édite ce site
>
> Ce site est édité par [NOM]. Pour toute question : [contact@livaside.app].
>
> Hébergeur : [NOM DE L'HÉBERGEUR], [adresse postale de l'hébergeur].
>
> ## Ce que ce site collecte
>
> Une seule chose : votre adresse e-mail, si vous la laissez dans le formulaire de liste
> d'attente. Rien d'autre.
>
> Ce site ne dépose **aucun cookie** et n'utilise **aucun outil de mesure d'audience ni aucun
> traceur**. Vous n'avez donc aucun bandeau à accepter ou à refuser.
>
> Ce site ne traite **aucune donnée de santé**. L'application Livaside, elle, en traitera : elle
> aura sa propre politique de confidentialité, publiée avant sa sortie.
>
> ## Votre adresse e-mail
>
> **Pourquoi nous la demandons.** Pour vous envoyer un e-mail lorsque la première version de
> l'application sera disponible. C'est le seul usage. Pas de lettre d'information, pas de
> publicité, pas de revente.
>
> **Sur quelle base.** Sur votre consentement : vous nous donnez votre adresse volontairement, et
> vous pouvez le retirer à tout moment (voir plus bas).
>
> **Qui y a accès.** [NOM] uniquement. [PHRASE DESTINATAIRE — voir §5 du présent document]
> Votre adresse n'est transmise à personne d'autre, n'est ni vendue, ni louée, ni échangée.
>
> **Combien de temps nous la gardons.** Jusqu'à l'envoi de l'e-mail annonçant la sortie, puis au
> maximum trois mois. Si l'application n'est pas sortie dans les vingt-quatre mois suivant votre
> inscription, votre adresse est supprimée sans que vous ayez à le demander.
>
> ## Vos droits
>
> Vous pouvez à tout moment :
>
> - savoir si nous avons votre adresse et en obtenir une copie ;
> - la faire corriger ;
> - la faire supprimer, ou retirer votre consentement — c'est le même geste, et chaque e-mail que
>   nous envoyons contient un lien de désinscription ;
> - vous opposer à son utilisation, ou en demander la portabilité.
>
> Une demande à [contact@livaside.app] suffit, sans justification à fournir. Nous répondons dans
> un délai d'un mois.
>
> Si notre réponse ne vous satisfait pas, vous pouvez saisir la Commission nationale de
> l'informatique et des libertés (CNIL), 3 place de Fontenoy, TSA 80715, 75334 Paris Cedex 07 —
> [cnil.fr](https://www.cnil.fr).

### Trois remarques sur ce texte

- **Pas de délégué à la protection des données.** Aucune des conditions de l'article 37 du RGPD
  n'est remplie ici. Ne mentionnez pas de DPO : une adresse de contact suffit et un DPO affiché
  sans en avoir désigné un est pire que rien.
- **La phrase « ce site ne traite aucune donnée de santé »** mérite d'y rester. Elle évite qu'un
  lecteur — ou un contrôleur — confonde le site et l'app, et elle prépare proprement la politique
  de l'app.
- **L'adresse de l'hébergeur** se trouve sur son site et dépend de la décision 2 de LIV-6. Je la
  fournis dès que l'hébergeur est choisi, si c'est utile.

---

## 4. Pied de page

`index.html:299-307` : ajouter le lien, à côté de « Nous écrire ».

> Mentions légales et confidentialité

Pointant vers `confidentialite.html`. Un seul lien, atteignable en un clic depuis toute la page.
C'est ce qui rend la mention courte du §1 conforme : sans ce lien, elle ne l'est pas.

---

## 5. Tally ou Formspree — mon avis, demandé dans LIV-10

**Tally. Sans hésitation, et ce n'est pas une question de principe mais de temps.**

Non, l'option américaine n'est pas disqualifiante en droit — je ne vais pas vous dire l'inverse.
Mais elle vous coûte du travail pour un service identique.

| | Tally | Formspree |
|---|---|---|
| Où vivent les adresses | Europe (Google Cloud, Belgique) ; société belge | États-Unis |
| Contrat de sous-traitance (art. 28) | Accepté automatiquement à la création du compte, rien à signer | À conclure |
| Transfert hors UE | Aucun pour les réponses de formulaire. Les sous-traitants américains (SendGrid, Stripe) ne concernent que des fonctions optionnelles qu'une liste d'attente n'utilise pas | Oui. Formspree s'appuie sur les clauses contractuelles types (art. 46 RGPD) |
| Ce que vous devez écrire en plus | Rien | Une analyse d'impact du transfert (recommandations 01/2020 du CEPD), plus la mention du transfert et de ses garanties dans la page du §3 (art. 13.1.f) |

Deux précisions factuelles, pour que la décision soit prise sur du solide :

- Je n'ai pas trouvé de certification de Formspree au titre du **cadre de protection des données
  UE–États-Unis** (*Data Privacy Framework*). Sans cette certification, on ne peut pas s'appuyer
  sur la décision d'adéquation : il reste la voie des clauses types, avec la paperasse qui va avec.
- La décision d'adéquation UE–États-Unis **est valide aujourd'hui**. Elle a résisté au recours
  Latombe (Tribunal de l'UE, T-553/23, 3 septembre 2025), mais un pourvoi est pendant devant la
  Cour de justice (C-703/25 P). Ce n'est pas un motif de panique, c'est un motif pour ne pas créer
  une dépendance américaine quand l'alternative européenne est gratuite et aussi simple.

**La phrase « Qui y a accès » de la page du §3 selon votre choix** — une seule à garder :

- **Tally** → « Le formulaire est hébergé par Tally (Tally BV, Belgique), qui conserve les
  adresses en Europe pour notre compte et n'en fait aucun autre usage. »
- **Formspree** → « Le formulaire est hébergé par Formspree (États-Unis), qui conserve les
  adresses pour notre compte et n'en fait aucun autre usage. Ce transfert hors de l'Union
  européenne est encadré par les clauses contractuelles types de la Commission européenne. »
- **mailto (option en place)** → « Votre message arrive directement dans notre boîte e-mail. Aucun
  outil tiers n'intervient. »

Si vous restez en `mailto`, notez que **vous** détenez alors les adresses dans votre messagerie :
la promesse de suppression du §1 porte sur votre boîte, et le fournisseur de votre messagerie
devient le destinataire technique. Ça reste la solution la plus légère, et la mention du §1 et la
page du §3 restent valables telles quelles.

---

## 6. Ce qu'il me faut du fondateur — deux réponses, trente secondes

Tout le reste est final. Il manque deux informations que je ne peux pas inventer, parce qu'elles
désignent une personne réelle :

1. **Sous quelle identité le site est-il publié ?** Votre nom propre, ou une société si elle
   existe déjà ? C'est à la fois l'éditeur du site (art. 1-1 LCEN) et le responsable du
   traitement (RGPD). Ça remplit `[NOM]`.
2. **Quelle adresse de contact publier ?** `index.html:303` porte encore
   `CONTACT@EXEMPLE.COM`. Une adresse dédiée du type `contact@livaside.app` est préférable à une
   adresse personnelle : c'est le point d'entrée des demandes d'accès et de suppression. Ça
   remplit `[contact@livaside.app]`.

Si vous publiez en nom propre et ne souhaitez pas afficher votre adresse postale : c'est prévu par
la LCEN pour un éditeur non professionnel, à condition de publier le nom et l'adresse de
l'hébergeur — c'est déjà ce que fait le texte du §3. Rien à changer.

---

## 7. Exigences transmises aux autres

**Content & Marketing (LIV-6)** — les quatre points de mise en œuvre :
- remplacer la mention du formulaire et le bloc données par les versions ci-dessus ;
- ajouter la mention sur le **second** formulaire (`index.html:286-293`), qui n'en a aucune ;
- ajouter le lien en pied de page vers `confidentialite.html` ;
- ne jamais écrire « ne quittent jamais votre iPhone » (raison en §2).

**iOS Engineer (LIV-2, LIV-3)** — une contrainte dure, à ne pas découvrir plus tard :
**pas de synchronisation CloudKit / iCloud du magasin SwiftData.** Deux raisons qui se cumulent.
La première est la promesse publique que cette page va porter. La seconde est une règle Apple
explicite : les applications « may not store personal health information in iCloud »
(App Store Review Guidelines, 5.1.3 (ii)). Autrement dit, activer la synchronisation iCloud sur
des données de santé n'est pas un arbitrage produit, c'est un motif de refus. La sauvegarde iCloud
de l'appareil par l'utilisateur est une autre chose et ne pose pas de problème.

**Backend & MCP Engineer** — l'accès MCP doit être **déclenché par l'utilisateur et révocable à
tout moment**. La page va le dire publiquement (§2), donc l'implémentation doit s'y conformer.
Je reviendrai sur le détail (périmètre des données exposées, journalisation) dans un ticket dédié
quand le service sera cadré.

---

## 8. Hors périmètre de ce ticket, mais déjà repéré pour la publication

Noté ici pour qu'on ne le découvre pas le jour du lancement. Rien à faire maintenant.

- **Une politique de confidentialité pour l'app est obligatoire** pour toute application, avec un
  lien dans App Store Connect **et** dans l'app (5.1.1 (i)). Elle doit dire quelles données sont
  collectées, comment, tous leurs usages, la durée de conservation et comment retirer son
  consentement ou demander la suppression. Celle du §3 ne la couvre pas : elle concerne le site.
- **Déclaration App Privacy.** « Data Not Collected » n'est défendable que si rien ne sort
  réellement de l'appareil. L'arrivée du service MCP change cette déclaration : à reprendre à ce
  moment-là.
- **5.1.3 (i)** : interdiction d'utiliser les données HealthKit pour la publicité, le marketing ou
  l'exploration de données, et obligation de déclarer précisément quelles données de santé sont
  lues. Compatible avec le produit tel qu'il est pensé — à vérifier au moment de la soumission.
- **Registre des traitements** (art. 30 RGPD) : deux lignes à écrire, pas urgent, je le produirai
  avec la politique de l'app.

---

## Limite de cet avis

Ce document est une analyse de conformité, pas un avis juridique définitif. Pour ce périmètre — une
page statique sans traceur qui collecte une adresse e-mail — il n'y a pas lieu de consulter un
avocat : le risque est faible et les règles sont claires. Je vous dirai quand ce ne sera plus le
cas. Les deux sujets qui le justifieront : la politique de confidentialité de l'app avec données de
santé au moment de la publication, et le cadrage juridique de l'accès MCP si des données de santé
transitent vers un service tiers.

## Sources

- [Article 13 du RGPD — information lors de la collecte directe](https://donneespersonnelles.fr/article-13-rgpd)
- [Mentions obligatoires d'un formulaire de collecte — approche en deux niveaux](https://www.donneespersonnelles.fr/formulaire-contact-rgpd)
- [Newsletter et RGPD : consentement, double opt-in](https://www.donneespersonnelles.fr/newsletter-rgpd)
- [Mentions légales : art. 1-1 LCEN depuis la loi SREN, éditeur non professionnel](https://www.simonnetavocat.fr/mentions-legales-dun-site-internet-obligations-sanctions-et-modele/)
- [App Store Review Guidelines — 5.1.1 (i) et 5.1.3](https://developer.apple.com/app-store/review/guidelines/)
- [Tally — hébergement des données et sous-traitants](https://tally.so/help/gdpr)
- [Formspree — sécurité et clauses contractuelles types](https://formspree.io/security/)
- [Tribunal de l'UE, affaire Latombe T-553/23, 3 septembre 2025](https://iapp.org/news/a/european-general-court-dismisses-latombe-challenge-upholds-eu-us-data-privacy-framework)
- [État du cadre UE–États-Unis en 2026, pourvoi C-703/25 P](https://europeanmartech.eu/blog/eu-us-data-privacy-framework-2026-status)
