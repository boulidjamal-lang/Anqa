// Plantages signalés dans TestFlight : quand l'app se ferme d'un coup, iOS
// propose au testeur de « partager » le rapport avec le développeur. Ce
// script lit ces rapports (API App Store Connect, betaFeedbackCrashSubmissions)
// et les derniers builds envoyés, pour savoir où et pourquoi l'app s'arrête.
//
// Clé App Store Connect : variables ASC_KEY_ID, ASC_ISSUER_ID et
// ASC_PRIVATE_KEY (secrets GitHub). Rien n'est affiché de la clé, ni
// l'adresse du testeur (elle n'est même pas demandée à l'API).
// Les rapports complets vont dans le dossier « plantages/ » (artefact du run) ;
// le journal du run n'en montre que l'essentiel : cause de l'arrêt et pile du
// fil qui a planté.
import crypto from 'node:crypto';
import fs from 'node:fs';

const { ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY } = process.env;
const API = 'https://api.appstoreconnect.apple.com/v1';
const BUNDLE_ID = process.env.BUNDLE_ID || 'com.jambou.askesis';
const SORTIE = 'plantages';

function jeton() {
  const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
  const maintenant = Math.floor(Date.now() / 1000);
  const corps = b64({ alg: 'ES256', kid: ASC_KEY_ID, typ: 'JWT' }) + '.'
    + b64({ iss: ASC_ISSUER_ID, iat: maintenant, exp: maintenant + 600, aud: 'appstoreconnect-v1' });
  const signature = crypto.sign('sha256', Buffer.from(corps), { key: ASC_PRIVATE_KEY, dsaEncoding: 'ieee-p1363' });
  return corps + '.' + signature.toString('base64url');
}

async function api(chemin) {
  const r = await fetch(API + chemin, { headers: { Authorization: 'Bearer ' + jeton() } });
  if (!r.ok) {
    let detail = '';
    try { detail = ((await r.json()).errors || []).map(e => e.detail || e.title).join(' ; '); } catch { /* corps vide */ }
    throw new Error(`GET ${chemin.split('?')[0]} : HTTP ${r.status}${detail ? ' — ' + detail : ''}`);
  }
  return r.json();
}

fs.mkdirSync(SORTIE, { recursive: true });

const { data: apps } = await api(`/apps?filter[bundleId]=${encodeURIComponent(BUNDLE_ID)}&fields[apps]=bundleId,name`);
const app = apps.find(a => a.attributes.bundleId === BUNDLE_ID);
if (!app) { console.log(`::error::app ${BUNDLE_ID} introuvable sur App Store Connect`); process.exit(1); }

// Les derniers builds : numéro, date d'envoi, état du traitement par Apple.
const builds = await api(`/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=6`
  + '&fields[builds]=version,uploadedDate,processingState,minOsVersion,expired');
const numeroDuBuild = new Map(builds.data.map(b => [b.id, b.attributes.version]));
console.log('Derniers builds :');
for (const b of builds.data) {
  const a = b.attributes;
  console.log(`  build ${a.version} — envoyé ${a.uploadedDate} — ${a.processingState}${a.expired ? ' (expiré)' : ''} — iOS ${a.minOsVersion} minimum`);
}

// Les rapports de plantage partagés par les testeurs, du plus récent au plus ancien.
const CHAMPS = 'createdDate,comment,deviceModel,osVersion,appUptimeInMilliseconds,architecture,connectionType,batteryPercentage,diskBytesAvailable,locale,build';
let liste;
try {
  liste = await api(`/apps/${app.id}/betaFeedbackCrashSubmissions?limit=50`
    + `&fields[betaFeedbackCrashSubmissions]=${CHAMPS}&include=build&fields[builds]=version`);
} catch (e) {
  console.log('::warning::' + e.message + ' (nouvel essai sans le numéro de build)');
  liste = await api(`/apps/${app.id}/betaFeedbackCrashSubmissions?limit=50&fields[betaFeedbackCrashSubmissions]=${CHAMPS.replace(',build', '')}`);
}
for (const b of liste.included || []) if (b.type === 'builds') numeroDuBuild.set(b.id, b.attributes.version);
const rapports = liste.data
  .map(s => ({ id: s.id, ...s.attributes, build: numeroDuBuild.get(s.relationships?.build?.data?.id) || '?' }))
  .sort((a, b) => String(b.createdDate).localeCompare(String(a.createdDate)));
console.log(`\nPlantages partagés depuis TestFlight : ${rapports.length}`);
if (!rapports.length) {
  console.log("::notice::Aucun rapport partagé : quand iOS propose « Partager » après une fermeture, il faut l'accepter pour qu'il arrive ici.");
  process.exit(0);
}
for (const r of rapports.slice(0, 15)) {
  console.log(`  ${r.createdDate} — build ${r.build} — ${r.deviceModel} iOS ${r.osVersion} — ouverte depuis ${Math.round((r.appUptimeInMilliseconds || 0) / 1000)} s`
    + (r.comment ? ` — « ${String(r.comment).slice(0, 200)} »` : ''));
}

// Le détail des plus récents : cause de l'arrêt et pile du fil qui a planté.
// Rapport au format JSON d'iOS (.ips : une ligne d'en-tête, puis le corps).
function essentielIps(texte) {
  const coupure = texte.indexOf('\n');
  if (coupure < 0) return null;
  let tete, corps;
  try { tete = JSON.parse(texte.slice(0, coupure)); corps = JSON.parse(texte.slice(coupure + 1)); } catch { return null; }
  const images = corps.usedImages || [];
  const cadre = (f, i) => {
    const img = images[f.imageIndex] || {};
    return `  ${String(i).padEnd(3)} ${String(img.name || '???').padEnd(34)} ${f.symbol ? f.symbol + (f.symbolLocation ? ' + ' + f.symbolLocation : '') : '+ 0x' + Number(f.imageOffset || 0).toString(16)}`
      + (f.sourceFile ? `  (${f.sourceFile}:${f.sourceLine})` : '');
  };
  const garde = [
    `App : ${tete.app_name || ''} ${tete.app_version || ''} (${tete.build_version || ''}) — ${tete.os_version || ''} — ${corps.modelCode || ''}`,
    `Exception : ${JSON.stringify(corps.exception || {})}`,
    `Arrêt : ${JSON.stringify(corps.termination || {})}`,
  ];
  if (corps.asi) garde.push(`Infos de l'app : ${JSON.stringify(corps.asi).slice(0, 1500)}`);
  if (corps.ktriageinfo) garde.push(`Noyau : ${String(corps.ktriageinfo).slice(0, 600)}`);
  if (corps.lastExceptionBacktrace) {
    garde.push('', 'Dernière exception :');
    corps.lastExceptionBacktrace.slice(0, 40).forEach((f, i) => garde.push(cadre(f, i)));
  }
  const fils = corps.threads || [];
  const fautif = fils.find(t => t.triggered) || fils[corps.faultingThread];
  if (fautif) {
    garde.push('', `Fil qui a planté (n° ${fils.indexOf(fautif)}${fautif.queue ? ', ' + fautif.queue : ''}${fautif.name ? ', ' + fautif.name : ''}) :`);
    (fautif.frames || []).slice(0, 45).forEach((f, i) => garde.push(cadre(f, i)));
  }
  return garde.join('\n');
}

function essentiel(texte) {
  const ips = essentielIps(texte);
  if (ips) return ips;
  const lignes = texte.split('\n');
  const garde = [];
  const entete = /^(Hardware Model|OS Version|Version|Launch Time|Date\/Time|Exception Type|Exception Subtype|Exception Codes|Exception Reason|Termination Reason|Termination Description|Triggered by Thread|Crashed Thread|Application Specific Information|Kernel Triage)\s*:/;
  for (const l of lignes) if (entete.test(l)) garde.push(l);
  // Pile du fil qui a planté (format texte « Thread N Crashed: » ou JSON .ips).
  const debut = lignes.findIndex(l => /^Thread \d+ Crashed/.test(l) || /^Last Exception Backtrace/.test(l));
  if (debut >= 0) {
    garde.push('');
    for (let i = debut; i < lignes.length && i < debut + 45; i++) { if (i > debut && !lignes[i].trim()) break; garde.push(lignes[i]); }
  }
  const asi = lignes.findIndex(l => /^Application Specific (Information|Backtrace)/.test(l));
  if (asi >= 0) for (let i = asi + 1; i < lignes.length && i < asi + 12 && lignes[i].trim(); i++) garde.push(lignes[i]);
  return garde.length ? garde.join('\n') : lignes.slice(0, 80).join('\n');
}

for (const r of rapports.slice(0, 6)) {
  let texte = '';
  try { texte = (await api(`/betaFeedbackCrashSubmissions/${r.id}/crashLog?fields[betaCrashLogs]=logText`)).data?.attributes?.logText || ''; }
  catch (e) { console.log('::warning::' + e.message); continue; }
  const nom = `${String(r.createdDate).replace(/[:.]/g, '-')}-build-${r.build}.txt`;
  fs.writeFileSync(`${SORTIE}/${nom}`, texte);
  console.log(`\n::group::Plantage du ${r.createdDate} (build ${r.build}, ${r.deviceModel}, iOS ${r.osVersion}) — ${nom}`);
  console.log(essentiel(texte));
  console.log('::endgroup::');
}
