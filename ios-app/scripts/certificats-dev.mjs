// Place pour les certificats de développement, avant de signer l'app.
//
// À chaque envoi, Xcode (signature automatique avec la clé App Store
// Connect) crée sur le Mac de GitHub un certificat « Apple Development »
// nommé « Created via API ». Sa clé privée disparaît avec ce Mac à la fin
// de la compilation : le certificat ne sert plus jamais, mais il compte dans
// la limite d'Apple. Une fois la limite atteinte, plus aucun envoi ne passe
// (« Your account has reached the maximum number of certificates »).
//
// Ce script révoque ces certificats-là, et eux seuls : uniquement des
// certificats de développement, uniquement ceux créés par l'API. Un
// certificat créé à la main (sur un Mac, dans Xcode ou sur le site
// d'Apple) n'est jamais touché, ni aucun certificat de distribution.
// L'app déjà envoyée et TestFlight n'en dépendent pas.
//
// Clé App Store Connect : variables ASC_KEY_ID, ASC_ISSUER_ID et
// ASC_PRIVATE_KEY (secrets GitHub). Rien n'est affiché de la clé ni des
// noms des certificats : seulement des nombres.
import crypto from 'node:crypto';

const { ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY } = process.env;
const API = 'https://api.appstoreconnect.apple.com/v1';

function jeton() {
  const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
  const maintenant = Math.floor(Date.now() / 1000);
  const corps = b64({ alg: 'ES256', kid: ASC_KEY_ID, typ: 'JWT' }) + '.'
    + b64({ iss: ASC_ISSUER_ID, iat: maintenant, exp: maintenant + 600, aud: 'appstoreconnect-v1' });
  const signature = crypto.sign('sha256', Buffer.from(corps), { key: ASC_PRIVATE_KEY, dsaEncoding: 'ieee-p1363' });
  return corps + '.' + signature.toString('base64url');
}

async function api(chemin, methode = 'GET') {
  const r = await fetch(API + chemin, { method: methode, headers: { Authorization: 'Bearer ' + jeton() } });
  if (!r.ok) throw new Error(`${methode} ${chemin.split('?')[0]} : HTTP ${r.status}`);
  return r.status === 204 ? null : r.json();
}

const DEVELOPPEMENT = ['DEVELOPMENT', 'IOS_DEVELOPMENT'];
const creeParApi = c => /created via api/i.test(`${c.attributes.name || ''} ${c.attributes.displayName || ''}`);

const { data } = await api('/certificates?limit=200');
const dev = data.filter(c => DEVELOPPEMENT.includes(c.attributes.certificateType));
const aRevoquer = dev.filter(creeParApi);
console.log(`Certificats : ${data.length} en tout, dont ${dev.length} de développement ; ${aRevoquer.length} créés par l'API, révoqués maintenant.`);
let faits = 0;
for (const c of aRevoquer) {
  try { await api('/certificates/' + c.id, 'DELETE'); faits++; }
  catch (e) { console.log('::warning::Révocation impossible : ' + e.message); }
}
console.log(`Révoqués : ${faits} / ${aRevoquer.length}.`);
if (dev.length - faits > 1) console.log(`::notice::Il reste ${dev.length - faits} certificats de développement créés à la main : s'ils bloquent, les révoquer sur developer.apple.com (Certificates).`);
