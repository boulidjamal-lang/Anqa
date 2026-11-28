# Anqa — app iPhone d'Askēsis

Ce dépôt contient l'app iOS (Capacitor + modules Swift) dans `ios-app/`, et sa compilation dans le cloud (`.github/workflows/ios.yml`).

L'appli web embarquée (index.html, données, pages légales) vit dans le dépôt **mon-coach** : la compilation la clone (`.source/`, par défaut la branche `base-build-33` : le design du build 33 avec toutes les fonctions du site, qui reste sur `main`) et `ios-app/scripts/preparer-www.mjs` la prépare pour l'app. Aucune copie n'est gardée ici.

## Ce que l'app ajoute au site

Barre d'onglets native (iOS 26), activité en direct de la séance (écran
verrouillé, Dynamic Island), widgets « Ma journée », « Prochaine séance » et
« Poids » (écran d'accueil et écran verrouillé), raccourcis Siri (démarrer la
séance, ajouter de l'eau, mon bilan), séance inscrite dans Santé, scanner,
vibrations, rappels, achats. Tout vit dans `ios-app/ios/App/` (Swift) et
`ios-app/src/natif.js` (le pont) ; la page web reste la source des données et
publie seulement un résumé dans le groupe d'apps pour les widgets.
