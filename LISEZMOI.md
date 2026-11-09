# Anqa — app iPhone d'Askēsis

Ce dépôt contient l'app iOS (Capacitor + modules Swift) dans `ios-app/`, et sa compilation dans le cloud (`.github/workflows/ios.yml`).

L'appli web embarquée (index.html, données, pages légales) vit dans le dépôt **mon-coach** : la compilation la clone (`.source/`) et `ios-app/scripts/preparer-www.mjs` la prépare pour l'app. Aucune copie n'est gardée ici.
