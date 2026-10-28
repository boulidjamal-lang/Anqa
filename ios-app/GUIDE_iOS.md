# Askēsis sur iPhone — guide de mise en service

L'app iOS est prête : c'est l'appli web (dépôt **Anqaa**) embarquée dans une
vraie app avec [Capacitor](https://capacitorjs.com/), plus les fonctions de
l'iPhone. **Pas besoin de Mac** : la compilation se fait sur un Mac de GitHub
(onglet *Actions* de ce dépôt), gratuitement puisque le dépôt est public.

## Ce qui est prêt

| Dans l'app | Comment |
|---|---|
| S'ouvre instantanément, même sans réseau | appli, bibliothèques et polices dans le téléphone |
| Vraies vibrations (série cochée, records, fin de repos) | moteur haptique de l'iPhone |
| Rappel de fin de repos, écran verrouillé | notification programmée, avec le bip de l'appli |
| Écran allumé pendant la séance | module natif |
| Scan de code-barres instantané | scanner plein écran d'iOS |
| Pas et poids automatiques | Apple Santé (Profil › Réglages › Appareils), jamais d'écrasement d'une saisie |
| Partage de l'image du bilan, « Enregistrer l'image » | feuille de partage d'iOS |
| Courbe en plein écran en paysage | rotation native |
| Pro payé via Apple (essai 14 jours) | achats intégrés, vérifiés par le serveur |

Et pour Apple (utile aussi sur le web) : **Supprimer mon compte** (Mon compte),
**accord avant l'IA** (demandé une fois, retirable), **Signaler / Bloquer** sous
la fiche d'un gymbro.

Le site web ne change pas : tout ce qui est propre à l'iPhone ne s'active que
dans l'app.

## Ce qu'il te faut

- Un compte **Apple Developer** : 99 $ par an.
- Ton iPhone, avec l'app **TestFlight** (gratuite, sur l'App Store) pour
  installer les versions d'essai.
- C'est tout : ni Mac, ni Xcode.

---

## Étape 0 — Voir l'app tourner, dès maintenant (sans compte Apple)

Dépôt **Anqa** › onglet **Actions** › **App iOS** › **Run workflow**.

En 15 à 20 minutes, un Mac de GitHub :

1. récupère la dernière version de l'appli (dépôt Anqaa) ;
2. compile l'app iOS ;
3. la lance dans un simulateur d'iPhone, remplie de données de
   démonstration ;
4. photographie chaque écran, en clair et en sombre.

Les captures sont sur la branche **captures-ios** du dépôt (menu des branches
› `captures-ios`, puis touche une image), et aussi dans **Artifacts ›
captures-simulateur**, en bas de la page de l'exécution. Elles ont déjà le
format demandé pour l'App Store (iPhone Pro Max).

## Étape 1 — Le compte Apple Developer (quelques jours)

1. [developer.apple.com/programs](https://developer.apple.com/programs/) ›
   **Enroll** › en tant que **particulier** (Individual). Apple vérifie ton
   identité.
2. Une fois accepté, dans [App Store Connect](https://appstoreconnect.apple.com)
   › **Accords, taxes et banque** :
   - signe l'accord **Applications payantes** ;
   - renseigne ton compte bancaire et tes informations fiscales.

   C'est ce qui permet de vendre Pro. Apple est le vendeur : il facture,
   encaisse et reverse la TVA de chaque pays.
3. Demande le **Small Business Program**
   ([lien](https://developer.apple.com/app-store/small-business-program/)) :
   Apple prend alors **15 %** au lieu de 30 %.

## Étape 2 — Créer l'app chez Apple (10 minutes)

1. [Certificates, IDs & Profiles](https://developer.apple.com/account/resources/identifiers/list)
   › **Identifiers** › **+** › *App IDs* › *App* :
   - description : `Askesis` ;
   - Bundle ID **explicite** : `com.jambou.askesis` ;
   - capacités : coche **HealthKit**.
2. [App Store Connect](https://appstoreconnect.apple.com) › **Apps** › **+** ›
   **Nouvelle app** :
   - plateforme iOS ;
   - nom `Askēsis` (s'il est déjà pris, une variante comme `Askēsis – Muscu & Nutrition`) ;
   - langue principale Français ;
   - Bundle ID `com.jambou.askesis` ;
   - SKU `askesis`.
3. Note ton **Team ID** : [Membership](https://developer.apple.com/account#MembershipDetailsCard),
   10 caractères.

> Tu veux un autre identifiant que `com.jambou.askesis` ? Dis-le-moi **avant
> la première soumission** (il ne change plus ensuite) : je le remplace dans
> le projet.

## Étape 3 — Relier GitHub à ton compte Apple (5 minutes)

1. App Store Connect › **Utilisateurs et accès** › **Intégrations** › **Clés
   API App Store Connect** › **+** :
   - nom `GitHub` ;
   - accès **Admin**, nécessaire pour que la compilation crée seule les
     certificats.

   Télécharge le fichier `.p8` : Apple ne le donne **qu'une fois**. Note le
   **Key ID** et l'**Issuer ID** affichés au-dessus de la liste.
2. GitHub › dépôt **Anqa** › **Settings** › **Secrets and variables** ›
   **Actions** :
   - onglet **Secrets**, trois secrets :
     - `ASC_KEY_ID` : le Key ID ;
     - `ASC_ISSUER_ID` : l'Issuer ID ;
     - `ASC_PRIVATE_KEY` : tout le contenu du fichier `.p8`, lignes
       `-----BEGIN…` et `-----END…` comprises ;
   - onglet **Variables** : `APPLE_TEAM_ID` = ton Team ID.

   **Ne m'envoie jamais ces clés** : elles ne vont que dans GitHub.
3. **Actions** › **App iOS** › **Run workflow** › coche **Envoyer aussi sur
   TestFlight** › **Run**.
4. App Store Connect › ton app › **TestFlight** :
   - ajoute-toi en **testeur interne** ;
   - sur l'iPhone, ouvre **TestFlight** et installe Askēsis.

À chaque nouvelle version de l'appli web, refais l'étape 3.3 : l'app récupère
toujours la dernière version du dépôt Anqaa.

## Étape 4 — Supabase (10 minutes, rien à migrer)

Ton projet Supabase reste le même, avec les mêmes comptes, tables et données.
Deux ajouts seulement :

1. **SQL** : dans l'appli, avec ton compte admin, va dans **Administration ›
   Réglages techniques**. Ouvre « **SQL : app iOS et App Store** », touche
   **Copier le SQL**, puis dans Supabase › **SQL Editor** › colle › **Run**.
   - Ce SQL permet à chacun de supprimer son compte et de signaler ou bloquer
     un gymbro. Il prépare aussi les abonnements Apple.
   - Il ne modifie aucune donnée existante et peut être relancé sans risque.
   - Les signalements arrivent dans la table `gymbros_signalements` : Apple
     demande d'y répondre sous 24 h.
2. **Liens des emails** : Supabase › **Authentication** › **URL
   Configuration** › **Redirect URLs**. Vérifie que
   `https://boulidjamal-lang.github.io/mon-coach/` y figure. Depuis l'app, les
   emails de confirmation et de mot de passe oublié mènent au site.
3. **Achats Apple**, une fois l'étape 5 faite :
   - Supabase › **Edge Functions** › **Deploy a new function** › **Via
     Editor** ;
   - nom : **`achats-apple`** ;
   - colle le contenu de `supabase/functions/achats-apple/index.ts` (dépôt
     Anqaa) ;
   - **désactive Verify JWT** : c'est Apple qui appelle, et la fonction
     vérifie elle-même chaque achat auprès d'Apple ;
   - Edge Functions › **Secrets** :
     - `APPLE_IAP_KEY_ID` et `APPLE_IAP_ISSUER_ID` : ceux de la clé
       d'achats intégrés (étape 5.2) ;
     - `APPLE_IAP_PRIVATE_KEY` : tout le contenu de son fichier `.p8` ;
     - `APPLE_BUNDLE_ID` : `com.jambou.askesis`.

## Étape 5 — Askēsis Pro via Apple

Dans une app iOS, Apple impose son propre paiement pour débloquer Pro. Le
paiement Stripe reste possible sur le web.

1. App Store Connect › ton app › **Monétisation** › **Abonnements** › groupe
   « **Askēsis Pro** », avec deux abonnements :

   | Identifiant | Durée | Prix | Offre d'introduction |
   |---|---|---|---|
   | `askesis.pro.an` | 1 an | 29,99 € | essai gratuit 14 jours |
   | `askesis.pro.mois` | 1 mois | 3,99 € | essai gratuit 14 jours |

   Pour chacun, ajoute :
   - un nom et une description en français ;
   - une capture de la fenêtre Pro (voir l'étape 0).
2. **Clé d'achats intégrés** : Utilisateurs et accès › Intégrations › **Achats
   intégrés** › **Générer**. Télécharge le `.p8`, note le Key ID, puis mets-les
   dans les secrets Supabase (étape 4.3).
3. **Notifications d'Apple** : App Store Connect › ton app › **Informations
   sur l'app** › **Notifications du serveur App Store** :
   - version 2 ;
   - URL de production **et** de bac à sable :
     `https://nhbvmqubwbzrddndisfr.supabase.co/functions/v1/achats-apple`.
4. Envoie-moi les deux identifiants (ce ne sont pas des secrets) : je les mets
   dans l'appli (`PRO_APPLE`). D'ici là, la fenêtre Pro de l'app affiche
   « bientôt disponible ».

Les membres fondateurs et les Pro offerts le restent, même s'ils s'abonnent
via Apple.

## Étape 6 — Avant de soumettre à Apple

- **Vidéos d'exercices** : elles viennent de SmartWorkout. Il faut leur
  **accord écrit** pour les utiliser dans une app vendue sur l'App Store.
  Sinon, je les retire de l'app (les fiches gardent consignes et dessins des
  muscles).
- **Pages légales** : complète les « À compléter » des mentions légales
  (contact) et de la confidentialité. La confidentialité doit aussi dire que :
  - l'app lit les pas et le poids dans Santé ;
  - ces données vont dans ton compte Askēsis ;
  - elles ne servent jamais à la publicité.

  Les CGV ne concernent que le paiement Stripe du site.
- **Compte de démonstration** pour l'équipe d'Apple (l'app demande de se
  connecter) : crée un compte de test avec quelques jours de données. Mets
  ses identifiants dans App Store Connect › **Informations pour la
  vérification de l'app**.
- **Confidentialité de l'app** (App Store Connect › App Privacy), données
  liées à la personne, sans suivi publicitaire :
  - Santé et forme : poids, pas, séances, repas ;
  - Coordonnées : email ;
  - Contenu : photos de progression ;
  - Identifiants : identifiant du compte.
- **Fiche App Store** :
  - catégorie **Santé et forme** ;
  - âge 4+ ;
  - captures (étape 0), description, mots-clés ;
  - URL de la politique de confidentialité :
    `https://boulidjamal-lang.github.io/mon-coach/confidentialite.html`.
- **Soumettre pour vérification**. Compte quelques heures à deux jours.

## Mises à jour de l'app

- **Version affichée** : `version` dans `ios-app/package.json` (1.0.0 au
  départ). Le numéro de build suit les exécutions de GitHub, tout seul.
- **Une nouvelle version** : relance la compilation avec TestFlight (étape
  3.3), vérifie sur ton iPhone, puis **Soumettre pour vérification** dans App
  Store Connect.

## Fichiers

- `ios-app/capacitor.config.json` : nom, identifiant, réglages des modules.
- `ios-app/scripts/preparer-www.mjs` : prépare l'appli embarquée depuis le
  dépôt Anqaa :
  - bibliothèques et polices locales, aux mêmes versions que le site ;
  - échec franc si une version change.
- `ios-app/src/natif.js` : le pont entre l'appli et les modules de l'iPhone.
- `ios-app/ios/` : le projet Xcode. Il contient les permissions en français
  (caméra, photos, Santé), HealthKit, l'icône (le T) et l'écran de lancement
  clair ou sombre.
- `.github/workflows/ios.yml` : la compilation dans le cloud, les captures du
  simulateur et l'envoi sur TestFlight.

Côté appli, dépôt Anqaa :

- la couche « APP iOS » d'`index.html`, inactive sur le web ;
- `supabase/functions/achats-apple/` ;
- les tests : le faux iPhone de `tests/outils.js`, les tests « app iOS » et
  les tests des achats Apple.
