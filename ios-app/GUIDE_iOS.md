# Askēsis sur l'App Store : guide pas à pas

L'app iOS est prête : c'est l'appli web (dépôt **Anqaa**) embarquée dans une
vraie app avec [Capacitor](https://capacitorjs.com/), plus les fonctions de
l'iPhone. **Pas besoin de Mac** : la compilation se fait sur un Mac de GitHub
(onglet *Actions* de ce dépôt), gratuitement puisque le dépôt est public.

Les textes à copier dans App Store Connect (fiche, confidentialité, notes pour
Apple) sont dans **[FICHE_APP_STORE.md](FICHE_APP_STORE.md)**.

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
| Pro payé via Apple (essai 14 jours) | achats intégrés `askesis.pro.an` et `askesis.pro.mois`, vérifiés par le serveur |

Et pour Apple :

- **Conditions acceptées** : deux cases à la création du compte (conditions
  d'utilisation, données de santé). Un compte plus ancien les accepte une fois,
  à sa connexion suivante.
- **Supprimer mon compte** (Réglages › Compte › Gérer).
- **Accord avant l'IA**, demandé une fois et retirable.
- **Signaler / Bloquer** sous la fiche d'un gymbro.
- **Pages légales version iPhone** : ouvertes depuis l'app, elles parlent du
  paiement par Apple et d'Apple Santé, sans Stripe.
- **Aucun contenu sans licence** : ni vidéo SmartWorkout, ni GIF ExerciseDB,
  ni image wger dans l'app. Les fiches montrent l'image d'une source libre
  (avec sa source) ou, pour la plupart, le schéma des muscles, consignes
  comprises. Le site, lui, garde les vidéos.
- **Manifeste de confidentialité** (`PrivacyInfo.xcprivacy`) exigé par Apple.

Le site web ne change pas : tout ce qui est propre à l'iPhone ne s'active que
dans l'app.

---

## Étape 0 — Faire apparaître le bouton « Run workflow »

GitHub ne montre ce bouton que si la compilation est sur la **branche par
défaut** du dépôt. Aujourd'hui, celle d'**Anqa** est une autre branche.

1. Dépôt **Anqa** › **Settings** › **General** › **Default branch** › icône
   des deux flèches.
2. Choisis `claude/html-to-iphone-app-cl9sj7` › **Update** › confirme.

Ensuite : **Actions** › **App iOS** › **Run workflow**. En 15 à 20 minutes, un
Mac de GitHub compile l'app, la lance dans un simulateur d'iPhone avec des
données de démonstration, et photographie chaque écran, en clair et en sombre.
Les captures sont sur la branche **captures-ios** et dans **Artifacts ›
captures-simulateur**. Elles ont le format d'écran demandé par l'App Store.

## Étape 1 — Contrats, banque et commission (à faire en premier)

Sans ces trois points, Apple refuse de vendre Pro.

1. [App Store Connect](https://appstoreconnect.apple.com) › **Accords, taxes
   et banque** :
   - signe l'accord **Applications payantes** ;
   - renseigne ton compte bancaire et tes informations fiscales.

   Apple est le vendeur : il facture, encaisse et reverse la TVA de chaque pays.
2. Demande le **Small Business Program**
   ([lien](https://developer.apple.com/app-store/small-business-program/)) :
   Apple prend alors **15 %** au lieu de 30 %.

## Étape 2 — Créer l'app chez Apple (10 minutes)

1. [Certificates, IDs & Profiles](https://developer.apple.com/account/resources/identifiers/list)
   › **Identifiers** › **+** › *App IDs* › *App* :
   - description : `Askesis` ;
   - Bundle ID **explicite** : `com.jambou.askesis` ;
   - capacités : coche **HealthKit** (les achats intégrés sont inclus d'office).
2. App Store Connect › **Apps** › **+** › **Nouvelle app** :
   - plateforme iOS ;
   - nom : voir la fiche (`Askēsis`, ou la variante proposée s'il est pris) ;
   - langue principale Français ;
   - Bundle ID `com.jambou.askesis` ;
   - SKU `askesis` ;
   - accès complet.
3. Note ton **Team ID** : [Membership](https://developer.apple.com/account#MembershipDetailsCard),
   10 caractères.

> Tu veux un autre identifiant que `com.jambou.askesis` ? Dis-le-moi **avant
> la première soumission** : il ne change plus ensuite.

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

## Étape 4 — Les abonnements Pro (20 minutes)

1. App Store Connect › ton app › **Monétisation** › **Abonnements** ›
   **Créer** un groupe : nom de référence `Askēsis Pro`. Dans le groupe,
   **Localisation** › Français : nom affiché `Askēsis Pro`.
2. Dans ce groupe, deux abonnements, **avec exactement ces identifiants** (ils
   sont déjà dans l'app) :

   | Nom de référence | Identifiant du produit | Durée | Prix (France) |
   |---|---|---|---|
   | Pro annuel | `askesis.pro.an` | 1 an | 29,99 € |
   | Pro mensuel | `askesis.pro.mois` | 1 mois | 3,99 € |

   Pour chacun :
   - **Prix de l'abonnement** : choisis le prix en euros pour la France ;
     Apple calcule les autres pays ;
   - **Localisation** › Français : nom et description de la fiche ;
   - **Offre d'introduction** › **Essai gratuit**, **2 semaines**, tous les
     pays ;
   - **Informations pour la vérification** : une capture de la fenêtre
     Askēsis Pro (branche `captures-ios`) et la note de la fiche.
3. **Clé d'achats intégrés** : Utilisateurs et accès › Intégrations › **Achats
   intégrés** › **Générer**. Télécharge le `.p8` et note son Key ID (étape 5.3).
4. **Notifications d'Apple** : ton app › **Informations sur l'app** ›
   **Notifications du serveur App Store** :
   - version 2 ;
   - URL de production **et** de bac à sable :
     `https://nhbvmqubwbzrddndisfr.supabase.co/functions/v1/achats-apple`.

Les membres fondateurs et les Pro offerts le restent, même s'ils s'abonnent
via Apple.

## Étape 5 — Supabase (10 minutes, rien à migrer)

Ton projet Supabase reste le même, avec les mêmes comptes, tables et données.

1. **SQL** : dans l'appli, avec ton compte admin, **Administration ›
   Réglages techniques** › « **SQL : app iOS et App Store** » › **Copier le
   SQL**, puis Supabase › **SQL Editor** › colle › **Run**.
   - Il permet de supprimer son compte, de signaler ou bloquer un gymbro, et
     prépare les abonnements Apple.
   - Il ne modifie aucune donnée existante et peut être relancé sans risque.
   - Les signalements arrivent dans **Administration › Signalements** :
     Apple demande d'y répondre sous 24 h.
2. **Liens des emails** : Supabase › **Authentication** › **URL
   Configuration** › **Redirect URLs** : vérifie que
   `https://boulidjamal-lang.github.io/mon-coach/` y figure.
3. **Fonction des achats Apple** :
   - Supabase › **Edge Functions** › **Deploy a new function** › **Via
     Editor** ;
   - nom : **`achats-apple`** ;
   - colle le contenu de `supabase/functions/achats-apple/index.ts` (dépôt
     Anqaa) ;
   - **désactive Verify JWT** : c'est Apple qui appelle, et la fonction
     vérifie elle-même chaque achat auprès d'Apple ;
   - Edge Functions › **Secrets** :
     - `APPLE_IAP_KEY_ID` et `APPLE_IAP_ISSUER_ID` : ceux de la clé
       d'achats intégrés (étape 4.3) ; l'Issuer ID est le même qu'à l'étape 3 ;
     - `APPLE_IAP_PRIVATE_KEY` : tout le contenu de son fichier `.p8` ;
     - `APPLE_BUNDLE_ID` : `com.jambou.askesis`.

## Étape 6 — Compiler et envoyer l'app (30 minutes, sans rien faire)

**Actions** › **App iOS** › **Run workflow** › coche **Envoyer aussi sur App
Store Connect** › **Run**.

Le Mac de GitHub compile, signe et envoie l'app. Elle apparaît dans App Store
Connect › ton app › onglet **TestFlight** après 15 à 30 minutes de traitement
chez Apple. C'est le passage obligé de tout build, **même sans utiliser
TestFlight** : tu le choisis ensuite dans la version à soumettre (étape 8). La
question sur le chiffrement est déjà réglée dans l'app (aucun chiffrement
propre).

> Facultatif mais conseillé : installe ce build sur ton iPhone avec l'app
> TestFlight et fais un achat de test. Il est gratuit, avec un compte
> « Sandbox » (Utilisateurs et accès › Sandbox).

## Étape 7 — La fiche App Store

Tout est dans **[FICHE_APP_STORE.md](FICHE_APP_STORE.md)** :

1. ton app › **Distribution** › version 1.0 : captures, texte promotionnel,
   description, mots-clés, URL d'assistance, copyright ;
2. **Informations sur l'app** : sous-titre, catégories, URL de la politique de
   confidentialité, droits sur le contenu, classification par âge ;
3. **Confidentialité de l'app** : les réponses de la fiche ;
4. **Tarifs et disponibilité** : gratuit, tous les pays (ou France seulement
   au début).

## Étape 8 — Soumettre

1. **Compte de démonstration** (l'app demande de se connecter) : crée un
   compte **neuf** avec quelques jours de repas, pesées et séances. Il ne doit
   être ni fondateur ni Pro offert : Apple doit pouvoir tester l'achat. Crée
   aussi un second compte, et rends-les gymbros, pour qu'Apple voie
   Signaler / Bloquer.
2. Version 1.0 › **Informations pour la vérification de l'app** : identifiants
   du compte de démonstration, et la note de la fiche.
3. Version 1.0 › **Build** : choisis celui de l'étape 6.
4. Version 1.0 › **Achats intégrés et abonnements** : coche **les deux
   abonnements**. Les premiers abonnements partent obligatoirement avec une
   version de l'app.
5. **Ajouter pour vérification** › **Soumettre**. Compte de quelques heures à
   deux jours.
6. Mise en vente : automatique dès l'acceptation, ou manuelle si tu préfères
   choisir le moment.

## Avant de soumettre : la liste

- [ ] Pages légales complétées : nom, SIRET, adresse, email de contact, région
      Supabase, mention de TVA, médiateur, date des membres fondateurs, date
      de version. Puis « Pousse », pour les mettre en ligne.
- [ ] SQL « app iOS et App Store » lancé (étape 5.1).
- [ ] Fonction `achats-apple` déployée avec ses quatre secrets (étape 5.3).
- [ ] Notifications du serveur App Store renseignées (étape 4.4).
- [ ] Les deux abonnements « Prêts à être soumis », essai de 2 semaines compris.
- [ ] Compte de démonstration neuf, avec des données et un gymbro.

## Mises à jour de l'app

- **Version affichée** : `version` dans `ios-app/package.json` (1.0.0 au
  départ). Le numéro de build suit les exécutions de GitHub, tout seul.
- **Une nouvelle version** : relance l'étape 6. Puis, dans App Store Connect,
  **+ Version** (ex. 1.0.1), choisis le nouveau build, **Soumettre**. L'app
  récupère toujours la dernière version du dépôt Anqaa.

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
- `supabase/functions/achats-apple/` ;
- les tests : le faux iPhone de `tests/outils.js`, les tests « app iOS » et
  les tests des achats Apple.
