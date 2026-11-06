# Askēsis sur l'App Store : guide pas à pas

L'app iOS est prête : c'est l'appli web (dépôt **Anqaa**) embarquée dans une
vraie app avec [Capacitor](https://capacitorjs.com/), plus les fonctions de
l'iPhone. **Pas besoin de Mac** : la compilation se fait sur un Mac de GitHub
(onglet *Actions* de ce dépôt), gratuitement puisque le dépôt est public.

Les textes à copier dans App Store Connect (fiche, confidentialité, notes pour
Apple) sont dans **[FICHE_APP_STORE.md](FICHE_APP_STORE.md)**.

**Première version : gratuite, sans vente.** Pro n'est pas vendu dans l'app
tant que tu n'as pas de statut pour vendre (micro-entreprise). En attendant,
rien n'y est verrouillé et Pro n'y est jamais mentionné ; seule l'IA reste
limitée à 3 essais par mois. La vente de Pro viendra dans une mise à jour
(voir « Plus tard » en bas).

## Ce qui est prêt

| Dans l'app | Comment |
|---|---|
| S'ouvre instantanément, même sans réseau | appli, bibliothèques et polices dans le téléphone |
| Vraies vibrations (série cochée, records, fin de repos) | moteur haptique de l'iPhone |
| Rappel de fin de repos, écran verrouillé | notification programmée, avec le bip de l'appli |
| Rappels (protéines, séance, pesée, eau) | notifications programmées sur l'iPhone |
| Écran allumé pendant la séance | module natif |
| Scan de code-barres instantané | scanner plein écran d'iOS |
| Pas et poids automatiques | Apple Santé (Profil › Réglages › Appareils), jamais d'écrasement d'une saisie |
| Partage de l'image du bilan, « Enregistrer l'image » | feuille de partage d'iOS |

Et pour Apple :

- **Conditions acceptées** : deux cases à la création du compte (conditions
  d'utilisation, données de santé). Un compte plus ancien les accepte une fois,
  à sa connexion suivante.
- **Supprimer mon compte** (Réglages › Compte › Gérer).
- **Accord avant l'IA**, demandé une fois et retirable.
- **Signaler / Bloquer** sous la fiche d'un gymbro.
- **Pages légales version iPhone** : ouvertes depuis l'app, elles parlent de
  l'app et d'Apple Santé, sans Stripe.
- **Aucun contenu sans licence** : ni vidéo SmartWorkout, ni GIF ExerciseDB,
  ni image wger dans l'app. Une fiche montre l'image d'une source libre (avec
  sa source) ou le mannequin des muscles travaillés. Le site, lui, garde les
  vidéos.
- **Manifeste de confidentialité** (`PrivacyInfo.xcprivacy`) exigé par Apple.

Le site web ne change pas : tout ce qui est propre à l'iPhone ne s'active que
dans l'app.

> Fais tout sur un **ordinateur** : les sites d'Apple et de GitHub y sont
> bien plus simples que sur l'iPhone. **Ne m'envoie jamais** un mot de passe,
> une clé ou ton IBAN.

---

## Étape 1 — Ton statut chez Apple (5 minutes)

1. Va sur [App Store Connect](https://appstoreconnect.apple.com) et connecte-toi
   avec l'identifiant Apple de ton compte développeur.
2. **Business** (ou « Accords, taxes et banque ») : l'accord **Free Apps**
   (applications gratuites) doit être **Actif**. Il l'est en général dès
   l'inscription ; sinon, accepte-le. Pas besoin de banque ni d'impôts pour
   une app gratuite.
3. Toujours dans **Business**, partie **Digital Services Act** (conformité
   pour l'Europe) : choisis **« Je ne suis pas un commerçant »**. L'app est
   gratuite et ne vend rien : ton adresse n'est pas affichée.

## Étape 2 — Faire apparaître le bouton « Run workflow » (2 minutes)

GitHub ne montre ce bouton que si la compilation est sur la **branche par
défaut** du dépôt. Aujourd'hui, celle d'**Anqa** est une autre branche.

1. Sur [github.com](https://github.com), ouvre le dépôt **Anqa** ›
   **Settings** (en haut à droite) › **General**.
2. Partie **Default branch** › icône des deux flèches.
3. Choisis `claude/html-to-iphone-app-cl9sj7` › **Update** › confirme.

## Étape 3 — Créer l'app chez Apple (10 minutes)

1. [Certificates, IDs & Profiles](https://developer.apple.com/account/resources/identifiers/list)
   › **Identifiers** › bouton **+** › *App IDs* › *App* › **Continue** :
   - Description : `Askesis` ;
   - Bundle ID : **Explicit**, `com.jambou.askesis` ;
   - dans la liste des capacités, coche **HealthKit** ;
   - **Continue** › **Register**.
2. [App Store Connect](https://appstoreconnect.apple.com) › **Apps** › bouton
   **+** › **Nouvelle app** :
   - plateforme **iOS** ;
   - nom : `Askēsis` (s'il est déjà pris : `Askēsis : muscu et nutrition`) ;
   - langue principale **Français** ;
   - Bundle ID : choisis `com.jambou.askesis` dans la liste ;
   - SKU : `askesis` ;
   - accès utilisateur : **Accès complet** ;
   - **Créer**.
3. Note ton **Team ID** (10 caractères) : [Membership](https://developer.apple.com/account#MembershipDetailsCard).

## Étape 4 — Relier GitHub à ton compte Apple (10 minutes)

1. App Store Connect › **Utilisateurs et accès** › onglet **Intégrations** ›
   **Clés API App Store Connect** › bouton **+** :
   - nom `GitHub` ;
   - accès **Admin** (la compilation crée seule les certificats) ;
   - **Générer**.

   **Télécharge** le fichier `.p8` : Apple ne le donne **qu'une fois**. Note le
   **Key ID** (sur la ligne de la clé) et l'**Issuer ID** (au-dessus de la
   liste).
2. GitHub › dépôt **Anqa** › **Settings** › **Secrets and variables** ›
   **Actions** :
   - onglet **Secrets** › **New repository secret**, trois fois :
     - nom `ASC_KEY_ID`, valeur : le Key ID ;
     - nom `ASC_ISSUER_ID`, valeur : l'Issuer ID ;
     - nom `ASC_PRIVATE_KEY`, valeur : ouvre le fichier `.p8` avec un éditeur
       de texte et colle **tout** son contenu, lignes `-----BEGIN…` et
       `-----END…` comprises ;
   - onglet **Variables** › **New repository variable** : nom
     `APPLE_TEAM_ID`, valeur : ton Team ID.

## Étape 5 — Supabase (10 minutes, rien à migrer)

Ton projet Supabase reste le même, avec les mêmes comptes et données.

1. **SQL** : dans l'appli, avec ton compte admin, **Administration ›
   Réglages techniques** › « **SQL : app iOS et App Store** » › **Copier le
   SQL**. Puis Supabase › **SQL Editor** › colle › **Run**.
   - Il permet de supprimer son compte, de signaler et de bloquer un gymbro.
   - Il ne modifie aucune donnée existante et peut être relancé sans risque.
   - Les signalements arrivent dans **Administration › Signalements** :
     Apple demande d'y répondre **sous 24 h**.
2. **Liens des emails** : Supabase › **Authentication** › **URL
   Configuration** › **Redirect URLs** : vérifie que
   `https://boulidjamal-lang.github.io/mon-coach/` y figure (sinon **Add
   URL**).

## Étape 6 — « Pousse » (moi), puis compiler et envoyer l'app (30 minutes)

1. Dis-moi « **Pousse** » : je mets en ligne l'appli et les pages légales.
2. GitHub › dépôt **Anqa** › **Actions** › **App iOS** (à gauche) › **Run
   workflow** › coche **Envoyer aussi sur App Store Connect** › **Run
   workflow**.
3. Attends la coche verte (20 à 30 minutes). Le build apparaît ensuite dans App
   Store Connect › ton app › onglet **TestFlight**, après 15 à 30 minutes de
   traitement chez Apple. C'est le passage obligé de tout build, **même sans
   utiliser TestFlight**.

En cas de croix rouge, envoie-moi une capture de l'étape en rouge.

> Facultatif : installe ce build sur ton iPhone avec l'app **TestFlight** pour
> l'essayer avant Apple.

## Étape 7 — La fiche App Store (30 minutes)

Tout est dans **[FICHE_APP_STORE.md](FICHE_APP_STORE.md)** :

1. ton app › **Distribution** › **1.0 Préparer pour la soumission** :
   captures, texte promotionnel, description, mots-clés, URL d'assistance,
   copyright ;
2. **Informations sur l'app** : sous-titre, catégories, URL de la politique de
   confidentialité, droits sur le contenu, classification par âge ;
3. **Confidentialité de l'app** : les réponses de la fiche ;
4. **Tarifs et disponibilité** : **Gratuit**, tous les pays (ou la France
   seulement au début).

Les captures : sur GitHub, dépôt **Anqa**, menu des branches › `captures-ios`.

## Étape 8 — Soumettre

1. **Compte de démonstration** (l'app demande de se connecter) : crée un
   compte **neuf** avec quelques jours de repas, pesées et séances. Crée aussi
   un second compte, et rends-les gymbros, pour qu'Apple voie
   Signaler / Bloquer.
2. Version 1.0 › **Informations pour la vérification de l'app** : coche
   « Connexion requise », mets les identifiants du compte de démonstration et
   la note de la fiche.
3. Version 1.0 › **Build** › **+** : choisis celui de l'étape 6.
4. **Ajouter pour vérification** › **Soumettre à App Review**. Compte de
   quelques heures à deux jours. Apple t'écrit par email.
5. Acceptée : elle sort toute seule (ou quand tu le décides, si tu as choisi
   la sortie manuelle).

## Avant de soumettre : la liste

- [ ] Pages légales : email de contact et région Supabase envoyés, puis
      « Pousse ».
- [ ] SQL « app iOS et App Store » lancé (étape 5.1).
- [ ] Compte de démonstration neuf, avec des données et un gymbro.

## Mises à jour de l'app

- **Version affichée** : `version` dans `ios-app/package.json` (1.0.0 au
  départ). Le numéro de build suit les exécutions de GitHub, tout seul.
- **Une nouvelle version** : relance l'étape 6.2. Puis, dans App Store
  Connect, **+** à côté de « iOS App » (ex. 1.0.1), choisis le nouveau build,
  **Soumettre**. L'app récupère toujours la dernière version du dépôt Anqaa.

---

## Plus tard : vendre Pro dans l'app

Tout est déjà écrit dans l'app ; il ne manque que ton statut et les réglages
chez Apple.

1. **Créer ta micro-entreprise** (formalites.entreprises.gouv.fr), attendre le
   SIRET. Envoie-le-moi pour les pages légales (avec la mention de TVA et un
   médiateur de la consommation, obligatoire pour vendre).
2. **Business** : accord **Paid Apps** (applications payantes), compte
   bancaire, formulaire fiscal **W-8BEN** ; statut DSA **« commerçant »**
   (adresse, téléphone et email affichés en Europe : une domiciliation évite
   d'y mettre ton adresse). Puis le **Small Business Program**
   ([lien](https://developer.apple.com/app-store/small-business-program/)) :
   Apple prend 15 % au lieu de 30 %.
3. **Abonnements** : ton app › **Monétisation** › **Abonnements** › groupe
   `Askēsis Pro` (nom affiché `Askēsis Pro`), avec **exactement** ces
   identifiants :

   | Nom de référence | Identifiant du produit | Durée | Prix (France) | Offre d'introduction |
   |---|---|---|---|---|
   | Pro annuel | `askesis.pro.an` | 1 an | 29,99 € | essai gratuit, 2 semaines |
   | Pro mensuel | `askesis.pro.mois` | 1 mois | 3,99 € | essai gratuit, 2 semaines |

   Pour chacun : localisation française (textes dans la fiche), capture de la
   fenêtre Askēsis Pro.
4. **Clé d'achats intégrés** : Utilisateurs et accès › Intégrations › **Achats
   intégrés** › **Générer** (garde le `.p8` et son Key ID).
5. **Supabase** › **Edge Functions** › **Deploy a new function** › **Via
   Editor** : nom **`achats-apple`**, contenu de
   `supabase/functions/achats-apple/index.ts` (dépôt Anqaa), **Verify JWT
   désactivé**. Secrets : `APPLE_IAP_KEY_ID`, `APPLE_IAP_ISSUER_ID` (le même
   qu'à l'étape 4), `APPLE_IAP_PRIVATE_KEY` (tout le `.p8`), `APPLE_BUNDLE_ID`
   = `com.jambou.askesis`.
6. **Notifications d'Apple** : **Informations sur l'app** › **Notifications
   du serveur App Store**, version 2, URL de production **et** de bac à sable :
   `https://nhbvmqubwbzrddndisfr.supabase.co/functions/v1/achats-apple`.
7. Dis-le-moi : je passe `PRO_EN_VENTE_APP` à `true` dans l'appli, j'ajoute
   l'historique d'achat au manifeste de confidentialité, et on soumet une
   version 1.1 **avec les deux abonnements cochés** dans sa page.

Les membres fondateurs et les Pro offerts le restent, même s'ils s'abonnent
via Apple.

## Fichiers

- `ios-app/capacitor.config.json` : nom, identifiant, réglages des modules.
- `ios-app/scripts/preparer-www.mjs` : prépare l'appli embarquée depuis le
  dépôt Anqaa :
  - bibliothèques et polices locales, aux mêmes versions que le site ;
  - échec franc si une version change ;
  - ni mini-vidéos ni identifiants SmartWorkout.
- `ios-app/src/natif.js` : le pont entre l'appli et les modules de l'iPhone.
- `ios-app/ios/` : le projet Xcode. Il contient les permissions en français
  (caméra, photos, Santé), HealthKit, le manifeste de confidentialité, l'icône
  (le T) et l'écran de lancement clair ou sombre.
- `.github/workflows/ios.yml` : la compilation dans le cloud, les captures du
  simulateur et l'envoi sur App Store Connect.

Côté appli, dépôt Anqaa :

- la couche « APP iOS » d'`index.html`, inactive sur le web ;
  `PRO_EN_VENTE_APP` y décide si Pro est vendu dans l'app ;
- `supabase/functions/achats-apple/` ;
- les tests : le faux iPhone de `tests/outils.js`, les tests « app iOS » et
  les tests des achats Apple.
