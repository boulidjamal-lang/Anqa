#!/usr/bin/env node
/* Prépare www/ : l'appli web (dépôt Anqaa) telle qu'elle tournera dans l'app iOS.
   - copie index.html, assets/ et les pages légales depuis la source ;
   - remplace les bibliothèques et polices venues d'Internet (CDN, Google
     Fonts) par des copies locales, aux mêmes versions : l'app s'ouvre sans
     réseau et ne dépend d'aucun service tiers au démarrage ;
   - ajoute natif.js (le pont vers les modules iOS) avant tout autre script ;
   - bloque le zoom (pincement, zoom sur un champ), comme une app native.
   Usage : node scripts/preparer-www.mjs [--source <dossier Anqaa>] [--capture]
   (par défaut .source/, où la compilation dans le cloud clone le dépôt).
   --capture : version de vérification seulement (jamais livrée), remplie de
   données de démonstration pour photographier chaque écran dans le simulateur. */
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const RACINE = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const iSource = args.indexOf('--source');
const SOURCE = resolve(iSource >= 0 ? args[iSource + 1] : (process.env.SOURCE_APPLI || join(RACINE, '.source')));
const WWW = join(RACINE, 'www');
const CAPTURE = args.includes('--capture');

function echec(message) { console.error('✗ ' + message); process.exit(1); }
if (!existsSync(join(SOURCE, 'index.html'))) echec(`index.html introuvable dans ${SOURCE} (option --source, ou clone du dépôt Anqaa dans .source/).`);

// Les bibliothèques chargées par l'appli depuis un CDN, et leur copie locale.
// La version demandée par index.html doit être celle installée ici : si
// l'appli web change de version, la compilation s'arrête plutôt que
// d'embarquer une autre version sans le dire.
const BIBLIOTHEQUES = [
  { motif: /https:\/\/unpkg\.com\/html5-qrcode@([\d.]+)\/html5-qrcode\.min\.js/, paquet: 'html5-qrcode', fichier: 'html5-qrcode.min.js', local: 'lib/html5-qrcode.min.js' },
  { motif: /https:\/\/cdn\.jsdelivr\.net\/npm\/chart\.js@([\d.]+)\/dist\/chart\.umd\.min\.js/, paquet: 'chart.js', fichier: 'dist/chart.umd.min.js', local: 'lib/chart.umd.min.js' },
  { motif: /https:\/\/cdn\.jsdelivr\.net\/npm\/@supabase\/supabase-js@([\d.]+)(?:\/dist\/umd\/supabase\.js)?(?=["'])/, paquet: '@supabase/supabase-js', fichier: 'dist/umd/supabase.js', local: 'lib/supabase.js' },
];

// Chemin direct : certains paquets (chart.js) n'exposent pas package.json à require.resolve.
function dossierPaquet(nom) {
  const d = join(RACINE, 'node_modules', nom);
  if (!existsSync(join(d, 'package.json'))) echec(`${nom} n'est pas installé : lance npm ci dans ios-app.`);
  return d;
}
function versionPaquet(nom) { return JSON.parse(readFileSync(join(dossierPaquet(nom), 'package.json'), 'utf8')).version; }
function commitSource() {
  try { return execFileSync('git', ['-C', SOURCE, 'rev-parse', '--short', 'HEAD'], { encoding: 'utf8' }).trim(); } catch (e) { return 'inconnu'; }
}

rmSync(WWW, { recursive: true, force: true });
mkdirSync(join(WWW, 'lib'), { recursive: true });

// 1) Fichiers de l'appli
for (const f of ['index.html', 'cgv.html', 'confidentialite.html', 'mentions-legales.html', 'assets/donnees.js']) {
  if (!existsSync(join(SOURCE, f))) echec(`${f} manque dans la source.`);
  cpSync(join(SOURCE, f), join(WWW, f));
}
cpSync(join(SOURCE, 'assets', 'miniatures'), join(WWW, 'assets', 'miniatures'), { recursive: true });
cpSync(join(RACINE, 'polices'), join(WWW, 'polices'), { recursive: true, filter: s => !/\.txt$/.test(s) || /OFL/.test(s) });
// Son de la notification de fin de repos : à la racine (c'est là que le module de notifications le cherche).
cpSync(join(RACINE, 'sons', 'fin-repos.wav'), join(WWW, 'fin-repos.wav'));

// 2) index.html : bibliothèques et polices locales, pont natif, zoom bloqué
let html = readFileSync(join(WWW, 'index.html'), 'utf8');
for (const b of BIBLIOTHEQUES) {
  // Seulement dans l'attribut src d'une balise <script> (pas dans un commentaire).
  const balise = new RegExp('(<script\\b[^>]*\\ssrc=")' + b.motif.source + '(")');
  const m = html.match(balise);
  if (!m) echec(`${b.paquet} n'est plus chargé comme prévu par index.html : mets à jour BIBLIOTHEQUES.`);
  const installee = versionPaquet(b.paquet);
  if (m[2] !== installee) echec(`index.html demande ${b.paquet}@${m[2]}, l'app iOS embarque ${installee} : aligne package.json.`);
  cpSync(join(dossierPaquet(b.paquet), b.fichier), join(WWW, b.local));
  html = html.replace(balise, (t, avant, version, apres) => avant + b.local + apres);
}
html = html.replace(/[ \t]*<link[^>]+href="https:\/\/fonts\.(?:googleapis|gstatic)\.com[^"]*"[^>]*>\n?/g, '');
html = html.replace(/<\/head>/i, '  <link rel="stylesheet" href="polices/polices.css">\n</head>');
const premierScript = html.search(/<script[\s>]/i);
if (premierScript < 0 || premierScript > html.search(/<\/head>/i)) echec('aucun script dans <head> : où placer natif.js ?');
html = html.slice(0, premierScript) + '<script src="natif.js"></script>\n  ' + html.slice(premierScript);
html = html.replace(/(<meta name="viewport" content=")([^"]*)(")/, (t, a, contenu, b) =>
  a + (/maximum-scale/.test(contenu) ? contenu : contenu + ', maximum-scale=1, user-scalable=no') + b);

if (CAPTURE) {
  cpSync(join(RACINE, 'scripts', 'capture-demo.js'), join(WWW, 'capture-demo.js'));
  html = html.replace(/<\/body>/i, '<script src="capture-demo.js"></script>\n</body>');
}

const restes = [...html.matchAll(/<(?:script|link)\b[^>]*(?:src|href)="(https?:\/\/[^"]+)"/gi)].map(m => m[1]);
if (restes.length) echec('ressources encore chargées depuis Internet au démarrage :\n  ' + restes.join('\n  '));
writeFileSync(join(WWW, 'index.html'), html);

// 3) natif.js (esbuild)
const version = `${JSON.parse(readFileSync(join(RACINE, 'package.json'), 'utf8')).version} (anqaa ${commitSource()})` + (CAPTURE ? ' — capture' : '');
const esbuild = await import('esbuild');
await esbuild.build({
  entryPoints: [join(RACINE, 'src', 'natif.js')], outfile: join(WWW, 'natif.js'),
  bundle: true, format: 'iife', minify: true, target: ['safari15'], legalComments: 'none',
  define: { __VERSION_APP__: JSON.stringify(version) },
});
writeFileSync(join(WWW, 'version-ios.json'), JSON.stringify({ version, prepare_le: new Date().toISOString() }, null, 2) + '\n');

// 4) Bilan
function taille(chemin) {
  const s = statSync(chemin);
  return s.isDirectory() ? readdirSync(chemin).reduce((t, f) => t + taille(join(chemin, f)), 0) : s.size;
}
const mo = n => (n / 1048576).toFixed(1) + ' Mo';
console.log(`✓ www/ prêt — ${version}`);
console.log(`  index.html ${mo(taille(join(WWW, 'index.html')))}, assets ${mo(taille(join(WWW, 'assets')))}, bibliothèques ${mo(taille(join(WWW, 'lib')))}, polices ${mo(taille(join(WWW, 'polices')))}, total ${mo(taille(WWW))}`);
