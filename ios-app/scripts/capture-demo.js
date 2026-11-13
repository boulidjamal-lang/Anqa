/* Compilation de vérification uniquement (preparer-www.mjs --capture) : ce
   fichier n'est jamais dans l'app livrée. Il remplit l'appli de données de
   démonstration (6 semaines de repas, poids, pas, eau, cardio et muscu), puis
   passe d'écran en écran. Le journal annonce chaque écran (« CAPTURE:repas »…)
   pour que la compilation dans le cloud prenne la capture au bon moment. */
(function () {
  // Les quatre onglets, puis une feuille ouverte et une séance réduite (au-dessus de la barre).
  const ECRANS = ['repas', 'seance', 'stats', 'reglages', 'feuille', 'accessoire'];
  const MONTRER = {
    feuille: () => { allerA('repas'); renderApp(); ouvrirFeuilleRepas('lunch'); },
    accessoire: async () => { allerA('seance'); await demarrerSeance(musculationProgrammes[0].id); allerA('repas'); renderApp(); }
  };
  // L'atlas musculaire 3D, quand la version embarquée de l'appli web l'a : sur la carte de la semaine, puis sur un
  // exercice animé (captures-simulateur.sh ajoute les deux mêmes écrans quand l'app contient assets/atlas).
  if (typeof ouvrirAtlas === 'function') {
    const squat = () => (toutesLesExercices().find(e => /^squat avec barre$/i.test(e.nom)) || toutesLesExercices().find(e => mouvementExercice(e.id)) || {}).id;
    ECRANS.push('atlas', 'atlas-exercice');
    MONTRER.atlas = () => montrerAtlas(null);
    MONTRER['atlas-exercice'] = () => montrerAtlas(squat());
    // La fiche d'un exercice montre son mouvement d'elle-même, quand la version embarquée de l'appli web le fait
    // (captures-simulateur.sh ajoute le même écran quand index.html contient monterMouvementFiche).
    // La fiche montrée est celle du développé militaire (à défaut, le squat) : un geste bras au-dessus de la tête, là où
    // les épaules et la course de la barre se jugent le mieux.
    const militaire = () => (toutesLesExercices().find(e => e.id === 'e39' && mouvementExercice(e.id)) || toutesLesExercices().find(e => /d[ée]velopp[ée] militaire/i.test(e.nom) && mouvementExercice(e.id)) || {}).id || squat();
    if (typeof monterMouvementFiche === 'function') { ECRANS.push('atlas-fiche'); MONTRER['atlas-fiche'] = () => montrerFicheAtlas(militaire()); }
  }
  function fermerFenetres() {
    // L'atlas rend sa carte graphique en se fermant (retirer la classe ne suffirait pas) ; le mouvement de la fiche aussi.
    if (typeof fermerSceneAtlas === 'function') { try { fermerSceneAtlas(); } catch (e) {} }
    if (typeof fermerMouvementFiche === 'function') { try { fermerMouvementFiche(); } catch (e) {} }
    document.querySelectorAll('.modal.show, .feuille.show').forEach(m => m.classList.remove('show'));
    document.body.classList.remove('couche-ouverte');
  }
  /* Le mouvement tourne-t-il ? On compte les images qu'il dessine en 2 s et, dans la même fenêtre, les tours du moteur
     web (requestAnimationFrame : chaque fois qu'il donne la main pour dessiner), dont ceux où l'appli dit le mouvement
     en lecture. Les machines de compilation calent parfois : au run 62, l'atlas a mis 77 s à s'ouvrir, une capture
     d'écran n'a pas répondu en 45 s, et cette mesure n'a vu qu'une image en 2 s là où la même version en dessinait 96
     un instant plus tôt. Une fenêtre où le moteur web n'a presque rien dessiné ne prouve donc rien : la mesure est
     refaite, douze fois au plus. Une fenêtre où il a dessiné vingt fois ou plus, mouvement en lecture, sans que le
     mouvement avance, est une faute établie : on s'arrête là. Avant chaque fenêtre, le mouvement est relancé puis on
     laisse 0,6 s à l'appli pour le remettre en pause si elle juge qu'il ne doit pas tourner (cadre hors de l'écran) :
     ce qui est compté, c'est ce que l'appli laisse tourner. Rend tous les essais ; le dernier est celui qui compte. */
  async function cadenceDuMouvement(images, relancer, lit, etat) {
    const pause = ms => new Promise(fin => setTimeout(fin, ms));
    const enLecture = () => { try { return !lit || !!lit(); } catch (e) { return false; } };
    const fenetre = async () => {
      if (relancer) { try { relancer(); } catch (e) { /* écran refermé entre-temps : la fenêtre le dira (aucune image) */ } }
      await pause(600);
      let tours = 0, lus = 0, compte = true;
      const tic = () => { if (!compte) return; tours++; if (enLecture()) lus++; requestAnimationFrame(tic); };
      requestAnimationFrame(tic);
      const avant = images(); await pause(2000); compte = false;
      return Object.assign({ images: images() - avant, tours_moteur_web: tours, tours_en_lecture: lus }, etat ? etat() : null);
    };
    const essais = [await fenetre()];
    const dernier = () => essais[essais.length - 1], fige = () => essais.some(x => x.images < 2 && x.tours_en_lecture >= 20);
    while (dernier().images < 2 && !fige() && essais.length < 12) { await pause(1000); essais.push(await fenetre()); }
    return essais;
  }
  const direCadence = essais => essais.map(x => x.images + ' image(s) pour ' + x.tours_moteur_web + ' tours du moteur web, dont ' + x.tours_en_lecture + ' en lecture').join(' ; ') + ' — par fenêtres de 2 s';
  /* L'atlas 3D dans le WebKit du simulateur : il doit se monter, dessiner, et ne laisser aucune erreur à la carte
     graphique ; sur un exercice, le mouvement doit tourner. Sinon la compilation échoue (CAPTURE:erreur), et rien
     n'est envoyé sur App Store Connect. Si le simulateur ne donne pas WebGL 2, on le dit sans échouer : l'atlas
     n'est alors pas vérifié ici. */
  async function montrerAtlas(exercice) {
    const pause = ms => new Promise(fin => setTimeout(fin, ms));
    const quoi = exercice ? 'atlas-exercice' : 'atlas';
    allerA(exercice ? 'seance' : 'repas'); renderApp();
    const essai = document.createElement('canvas').getContext('webgl2');
    if (!essai) { console.log('CAPTURE:' + quoi + '-sans-webgl2 (ce simulateur ne donne pas WebGL 2 : atlas non vérifié ici)'); return; }
    const info = essai.getExtension('WEBGL_debug_renderer_info');
    const carte = String(info ? essai.getParameter(info.UNMASKED_RENDERER_WEBGL) : essai.getParameter(essai.RENDERER));
    const perdre = essai.getExtension('WEBGL_lose_context'); if (perdre) perdre.loseContext();
    const debut = Date.now();
    await ouvrirAtlas('semaine', exercice ? { exercice } : undefined);
    // Monté, et une première image dessinée (12 s au plus).
    for (let k = 0; k < 48 && !(atlasMonte && atlasMonte.atlas.mesures().images >= 1); k++) await pause(250);
    if (!atlasMonte) {
      const message = (document.querySelector('#atlas-scene [role="alert"]') || {}).textContent || 'aucun message';
      console.log("CAPTURE:erreur l'atlas 3D ne se monte pas dans ce WebKit (" + quoi + ' ; ' + message + ' ; carte : ' + carte + ')'); return;
    }
    const pret = Date.now() - debut, toile = document.querySelector('#atlas-scene canvas'), gl = toile && toile.getContext('webgl2');
    // Sur un exercice, la cadence est jugée (voir cadenceDuMouvement) ; la carte, immobile, n'est que notée.
    const vue = atlasMonte, compter = () => vue.atlas.mesures().images;
    const essais = exercice ? await cadenceDuMouvement(compter, () => { if (vue.lecture) vue.lecture(true); }, () => !vue.lecture || vue.lecture())
      : await (async () => { const i0 = compter(); await pause(2000); return [{ images: compter() - i0 }]; })();
    if (!atlasMonte) { console.log("CAPTURE:erreur l'atlas 3D s'est refermé pendant la mesure (" + quoi + ')'); return; }
    const m = atlasMonte.atlas.mesures(), e = atlasMonte.etat(), erreurGl = gl ? gl.getError() : -1;
    const bilan = { pret_ms: pret, images_en_2s: essais[essais.length - 1].images, dernier_dessin_ms: Math.round(m.dernierTempsMs * 10) / 10, appels: m.appelsDeDessin, peau: m.peau, mode: e.mode,
      toile: m.largeur + 'x' + m.hauteur, pixels: m.pixels, anime: !!(atlasMonte.animation && atlasMonte.animation()), titre: (document.getElementById('titre-atlas') || {}).textContent, erreur_gl: erreurGl,
      premier_sommet: m.premierSommet == null ? 'inconnu' : m.premierSommet, carte };
    if (exercice) bilan.tours_moteur_web_en_2s = essais[essais.length - 1].tours_moteur_web;
    if (essais.length > 1) bilan.essais_cadence = essais;
    // Mesure comparée, sur la même machine et dans la même minute : l'écorché sans peau (0) et la peau entière (2),
    // que l'appli ne propose plus, face à l'apparence de l'appli (1, mesurée ci-dessus). Les machines de compilation
    // vont du simple au quintuple d'une fois sur l'autre : seule cette comparaison dit ce que coûte une apparence.
    if (exercice && atlasMonte.atlas.aPeau) {
      const cadence = async niveau => { atlasMonte.atlas.niveauPeau(niveau); await pause(300); const a = atlasMonte.atlas.mesures().images; await pause(2000); return atlasMonte.atlas.mesures().images - a; };
      bilan.images_sans_peau_en_2s = await cadence(0);
      bilan.images_peau_entiere_en_2s = await cadence(2);
      atlasMonte.atlas.niveauPeau(1); await pause(300);
      bilan.triangles_par_image = atlasMonte.atlas.mesures().trianglesSoumis || 'inconnu';
      bilan.erreur_gl_apparences = gl ? gl.getError() : -1;
    }
    const fautes = [];
    if (bilan.erreur_gl_apparences) fautes.push('erreur de la carte graphique ' + bilan.erreur_gl_apparences + " en changeant d'apparence");
    if (m.images < 1) fautes.push('aucune image dessinée');
    if (erreurGl) fautes.push('erreur de la carte graphique ' + erreurGl);
    if (gl && gl.isContextLost()) fautes.push('contexte graphique perdu');
    if (exercice && !bilan.anime) fautes.push("l'exercice n'est pas animé");
    if (exercice && bilan.images_en_2s < 2) fautes.push('le mouvement ne tourne pas (' + direCadence(essais) + ')');
    if (exercice && e.mode !== 'exercice') fautes.push('mode ' + e.mode + " au lieu d'« exercice »");
    console.log((fautes.length ? "CAPTURE:erreur l'atlas 3D (" + quoi + ') : ' + fautes.join(' ; ') + ' ' : 'CAPTURE:' + quoi + '-ok ') + JSON.stringify(bilan));
  }
  /* La fiche d'un exercice dans le WebKit du simulateur : en l'ouvrant, le corps doit exécuter le mouvement sans
     qu'on touche à rien (c'est ce que voit la personne qui touche un exercice). Puis l'atlas ouvert depuis la fiche
     doit passer DEVANT elle — au build 53 il s'ouvrait derrière, et l'on ne voyait rien. Mêmes verdicts que pour
     l'atlas : CAPTURE:atlas-fiche-ok, CAPTURE:erreur (la compilation s'arrête) ou sans-webgl2. */
  async function montrerFicheAtlas(id) {
    const pause = ms => new Promise(fin => setTimeout(fin, ms));
    allerA('seance'); renderApp();
    const essai = document.createElement('canvas').getContext('webgl2');
    if (!essai) { console.log('CAPTURE:atlas-fiche-sans-webgl2 (ce simulateur ne donne pas WebGL 2 : fiche non vérifiée ici)'); return; }
    const perdre = essai.getExtension('WEBGL_lose_context'); if (perdre) perdre.loseContext();
    const debut = Date.now();
    afficherFicheExerciceBiblio(id);
    // Monté, et une première image dessinée (15 s au plus).
    const monte = async () => { for (let k = 0; k < 60 && !(ficheMouvement && ficheMouvement.apercu.atlas.mesures().images >= 1); k++) await pause(250); return !!ficheMouvement; };
    if (!(await monte())) {
      console.log("CAPTURE:erreur la fiche d'un exercice ne montre pas son mouvement dans ce WebKit (cadre : " + !!document.getElementById('fiche-exo-3d') + ' ; repli sur la photo : ' + !!document.querySelector('#fiche-exo-media .fiche-exo-image') + ')'); return;
    }
    const pret = Date.now() - debut, a = ficheMouvement.apercu.atlas, toile = document.querySelector('#fiche-exo-3d canvas'), gl = toile && toile.getContext('webgl2');
    // Le simulateur peut demander moins d'animations : le mouvement est lancé pour être mesuré (voir cadenceDuMouvement).
    // Chaque essai note aussi ce que l'appli pense du cadre : visible ou non, en lecture ou non.
    const fiche = ficheMouvement, cadre = document.getElementById('fiche-exo-3d');
    const essais = await cadenceDuMouvement(() => a.mesures().images,
      () => { if (ficheMouvement === fiche) { fiche.voulu = true; fiche.apercu.lecture(true); } },
      () => ficheMouvement === fiche && fiche.apercu.lecture(),
      () => ({ en_lecture: ficheMouvement === fiche && !!fiche.apercu.lecture(), cadre_visible: typeof cadreFicheVisible === 'function' && cadre ? cadreFicheVisible(cadre) : null, page_cachee: document.hidden }));
    if (ficheMouvement !== fiche) { console.log("CAPTURE:erreur la fiche d'un exercice (atlas-fiche) : le mouvement a été démonté pendant la mesure " + JSON.stringify(essais)); return; }
    const m = a.mesures(), erreurGl = gl ? gl.getError() : -1, boite = toile.getBoundingClientRect();
    const bilan = { pret_ms: pret, images_en_2s: essais[essais.length - 1].images, tours_moteur_web_en_2s: essais[essais.length - 1].tours_moteur_web, dernier_dessin_ms: Math.round(m.dernierTempsMs * 10) / 10, appels: m.appelsDeDessin, peau: m.peau,
      toile: m.largeur + 'x' + m.hauteur, pixels: m.pixels, anime: !!ficheMouvement.apercu.anime, titre: (document.getElementById('titre-fiche-exercice') || {}).textContent, erreur_gl: erreurGl,
      premier_sommet: m.premierSommet == null ? 'inconnu' : m.premierSommet, visible: boite.width > 100 && boite.height > 100 && boite.top < innerHeight };
    if (essais.length > 1) bilan.essais_cadence = essais;
    const fautes = [];
    if (m.images < 1) fautes.push('aucune image dessinée');
    if (erreurGl) fautes.push('erreur de la carte graphique ' + erreurGl);
    if (gl && gl.isContextLost()) fautes.push('contexte graphique perdu');
    if (!bilan.anime) fautes.push("l'exercice n'est pas animé");
    if (bilan.images_en_2s < 2) fautes.push('le mouvement ne tourne pas (' + direCadence(essais) + ')');
    if (m.peau !== 1) fautes.push('peau ' + m.peau + ' au lieu de la peau partielle');
    // La peau gardée a la teinte du corps (version de l'appli web qui sait le dire) : ni teinte de chair, ni autre gris.
    if (a.apparence) {
      const ap = a.apparence(), attendu = typeof neutresExerciceAtlas === 'function' ? neutresExerciceAtlas().peau : null;
      bilan.teinte_peau = ap.teint;
      if (ap.chair !== 0 || (attendu && ap.teint !== attendu)) fautes.push('la peau n\'a pas la teinte du corps (' + ap.teint + ', chair ' + ap.chair + ')');
    }
    if (!bilan.visible) fautes.push("le cadre du mouvement n'est pas à l'écran");
    // L'atlas ouvert depuis la fiche : au premier plan. Puis on le referme, et la fiche reprend son mouvement
    // (c'est elle que la capture doit montrer).
    agrandirMouvementFiche();
    for (let k = 0; k < 48 && !(atlasMonte && atlasMonte.atlas.mesures().images >= 1); k++) await pause(250);
    const dessus = document.elementFromPoint(innerWidth / 2, innerHeight / 2);
    bilan.atlas_devant = !!(atlasMonte && dessus && dessus.closest('#atlas-modal'));
    if (!bilan.atlas_devant) fautes.push("l'atlas ouvert depuis la fiche n'est pas au premier plan");
    fermerAtlas();
    bilan.reprise = await monte();
    if (!bilan.reprise) fautes.push("le mouvement de la fiche ne reprend pas après l'atlas");
    else { ficheMouvement.voulu = true; ficheMouvement.apercu.lecture(true); }
    // Le soulevé de terre, calculé dans ce moteur (sans changer d'écran) : sa posture se règle à l'ouverture, sur le corps
    // et la peau du modèle. Du sol à la position debout, les genoux doivent se tendre sans jamais se verrouiller à
    // mi-course, et la barre rester près des chevilles. (Version de l'appli web qui règle le geste en poses clés.)
    try {
      const M = window.AnqaMouvements, moteur = bilan.reprise && ficheMouvement.apercu.atlas;
      if (M && M.Corps && moteur && moteur.squelette) {
        const corps = new M.Corps(moteur.squelette, moteur.peau ? regions => moteur.peau(regions) : null);
        const t0 = performance.now(), d = M.definir('souleve', corps, M.TEINTES.sombre), duree = performance.now() - t0, genoux = [], barre = [];
        for (let i = 0; i <= 4; i++) {
          const info = corps.poser(M.poseA(d, 0, i / 4)), h = info.hanches.G, g = info.genoux.G, c = info.chevilles.G, v1 = h.clone().sub(g), v2 = c.clone().sub(g);
          genoux.push(Math.round(Math.acos(v1.dot(v2) / v1.length() / v2.length()) * 180 / Math.PI)); barre.push(Math.round((info.prises.G.z - c.z) * 100));
        }
        bilan.souleve = { poses_cles: d.cles ? d.cles.length : 0, regle_en_ms: Math.round(duree), genoux, barre_devant_cheville_cm: barre };
        if (d.cles) {
          if (!genoux.every((x, i) => !i || x >= genoux[i - 1]) || genoux[0] > 125 || genoux[2] > 160 || genoux[4] < 168) fautes.push('soulevé de terre : genoux ' + genoux.join(', ') + ' (attendu : pliés au sol, encore pliés à mi-course, tendus debout)');
          if (Math.min.apply(null, barre) < 3 || Math.max.apply(null, barre) > 13) fautes.push('soulevé de terre : la barre s\'écarte des jambes (' + barre.join(', ') + ' cm devant la cheville)');
        }
      }
    } catch (e) { fautes.push('soulevé de terre : ' + String(e && e.message || e)); }
    // Le développé militaire et la traction, calculés dans ce moteur. Développé : la barre contourne le visage et les bras
    // finissent tendus. Traction : pendu bras tendus, mains sur la barre fixe (2,42 m). Jugés seulement avec la version de
    // l'appli web qui règle le développé en poses clés (les versions d'avant ne le faisaient pas : rien à leur reprocher ici).
    try {
      const M = window.AnqaMouvements, moteur = bilan.reprise && ficheMouvement.apercu.atlas;
      if (M && M.Corps && moteur && moteur.squelette) {
        const corps = new M.Corps(moteur.squelette, moteur.peau ? regions => moteur.peau(regions) : null);
        const t0 = performance.now(), d = M.definir('developpe epaules barre', corps, M.TEINTES.sombre), duree = performance.now() - t0, coudes = [];
        let tete = Infinity;
        for (let i = 0; i <= 10; i++) {
          const info = corps.poser(M.poseA(d, 0, i / 10)), pr = info.prises.G;
          coudes.push(Math.round(info.angles.G.coude));
          if (corps.peauPosee) corps.peauPosee(['tete'], (x, y, z) => { tete = Math.min(tete, Math.hypot(y - pr.y, z - pr.z) - 0.0135); }, true);
        }
        const source = moteur.peau ? moteur.peau(['epaule']) : null;
        bilan.militaire = { poses_cles: d.cles ? d.cles.length : 0, regle_en_ms: Math.round(duree), coudes, tete_au_plus_pres_mm: isFinite(tete) ? Math.round(tete * 1000) : null, epaule_par_la_corde: !!(source && source.C) };
        const dt = M.definir('traction', corps, M.TEINTES.sombre), surBarre = info => Math.round(Math.hypot(info.prises.G.y - 2.42, info.prises.G.z - 0.02) * 1000);
        const pendu = corps.poser(M.poseA(dt, 0, 0)), coudePendu = Math.round(pendu.angles.G.coude), mains = [surBarre(pendu), surBarre(corps.poser(M.poseA(dt, 0, 0.5))), surBarre(corps.poser(M.poseA(dt, 0, 1)))];
        bilan.traction = { coude_pendu: coudePendu, main_a_mm_de_la_barre: mains };
        if (d.cles) {
          if (coudes[10] > 15 || coudes[0] > 152) fautes.push('développé militaire : coudes ' + coudes.join(', ') + ' (attendu : tendus en haut)');
          if (!(tete > 0.012)) fautes.push('développé militaire : la barre passe à ' + Math.round(tete * 1000) + ' mm de la tête');
          if (!bilan.militaire.epaule_par_la_corde) fautes.push("le moteur ne donne pas la part « par la corde » de l'épaule");
          if (coudePendu > 16 || coudePendu < 3) fautes.push('traction : pendu, coude à ' + coudePendu + '°');
          if (Math.max.apply(null, mains) > 6) fautes.push('traction : mains à ' + mains.join(', ') + ' mm de la barre');
        }
      }
    } catch (e) { fautes.push('développé militaire : ' + String(e && e.message || e)); }
    console.log((fautes.length ? "CAPTURE:erreur la fiche d'un exercice (atlas-fiche) : " + fautes.join(' ; ') + ' ' : 'CAPTURE:atlas-fiche-ok ') + JSON.stringify(bilan));
  }
  function remplirDemo() {
    const t = todayStr();
    // Pas de séance laissée en cours par la passe précédente (clair puis sombre).
    musculationSessionActive = null; sauvegarderSessionActive();
    Object.assign(userProfile, { gender: 'm', age: 29, height: 178, pasHabituels: 8000, poidsVise: 76,
      onboarding: new Date().toISOString(), tutorielVu: true, premiersPas: { interets: ['nutrition', 'muscu', 'cardio'], masque: true } });
    userProfile.mesures = {};
    const R = (a, b) => a + Math.random() * (b - a);
    const al = (name, grams, k, p, c, f, unite) => ({ name, grams, unite: unite || 'g', kcal: k * grams / 100, p: p * grams / 100, c: c * grams / 100, f: f * grams / 100 });
    const petitsDej = [[al("Flocons d'avoine", 60, 372, 13.5, 58.7, 7), al('Lait demi-écrémé', 250, 46, 3.3, 4.8, 1.6, 'ml'), al('Banane', 120, 90, 1.1, 20, 0.3)],
      [al('Pain complet', 80, 247, 9, 41, 3.4), al('Œufs brouillés', 120, 155, 12.6, 1.1, 11), al('Avocat', 60, 160, 2, 8.5, 14.7)],
      [al('Skyr nature', 200, 63, 11, 4, 0.2), al('Granola', 40, 450, 9, 64, 16), al('Myrtilles', 80, 57, 0.7, 14, 0.3)]];
    const dejeuners = [[al('Blanc de poulet grillé', 150, 165, 31, 0, 3.6), al('Riz basmati cuit', 200, 130, 2.7, 28, 0.3), al('Brocolis vapeur', 150, 35, 2.8, 7, 0.4), al("Huile d'olive", 10, 884, 0, 0, 100)],
      [al('Pâtes complètes cuites', 220, 149, 5.8, 30, 0.9), al('Bœuf haché 5 %', 125, 137, 21, 0, 5), al('Sauce tomate', 100, 45, 1.6, 7, 1.2), al('Parmesan', 15, 392, 36, 0, 26)],
      [al('Saumon', 140, 208, 20, 0, 13), al('Quinoa cuit', 180, 120, 4.4, 21, 1.9), al('Courgettes', 150, 17, 1.2, 3.1, 0.3)]];
    const collations = [[al('Amandes', 30, 579, 21, 22, 50), al('Pomme', 150, 52, 0.3, 14, 0.2)], [al('Whey', 30, 400, 78, 8, 6), al('Banane', 120, 90, 1.1, 20, 0.3)], [al('Fromage blanc 0 %', 200, 45, 7.5, 4, 0.1), al('Miel', 15, 304, 0.3, 82, 0)]];
    const diners = [[al('Cabillaud', 180, 82, 18, 0, 0.7), al('Patate douce', 250, 86, 1.6, 20, 0.1), al('Haricots verts', 150, 31, 1.8, 7, 0.2)],
      [al('Omelette 3 œufs', 180, 154, 11, 1, 11), al('Salade composée', 200, 60, 2, 8, 2.5), al('Pain complet', 50, 247, 9, 41, 3.4)],
      [al('Dinde', 150, 135, 29, 0, 1.5), al('Lentilles cuites', 200, 116, 9, 20, 0.4), al('Carottes', 120, 41, 0.9, 10, 0.2)]];
    const N = 42;
    for (let k = N; k >= 0; k--) {
      const d = shiftDate(t, -k), jour = getDay(d);
      if (k === N) jour.goal = 'seche';
      jour.weight = Math.round((79 + (k / N) * 2.4 + R(-0.35, 0.35)) * 10) / 10;
      const pick = arr => JSON.parse(JSON.stringify(arr[Math.floor(Math.random() * arr.length)]));
      jour.meals.breakfast = pick(petitsDej);
      jour.meals.lunch = pick(dejeuners);
      if (k > 0) { jour.meals.snack = pick(collations); jour.meals.dinner = pick(diners); }
      jour.steps = k === 0 ? 5230 : Math.round(R(5500, 12500));
      jour.eauMl = k === 0 ? 1250 : Math.round(R(1400, 2600) / 250) * 250;
      if (k % 7 === 2 || k % 7 === 5) jour.workouts.push({ type: 'course', time: Math.round(R(28, 45)), distance: Math.round(R(5, 8.5) * 10) / 10, intensite: 2 });
      if (k % 7 === 0) userProfile.mesures[d] = { poids: jour.weight, grassePct: Math.round((17.5 + k / 14) * 10) / 10, muscleKg: 36.4 - k / 60, osKg: 3.2, eauPct: 58 };
      saveData(d);
    }
    // Musculation : 3 programmes et 6 semaines de séances avec progression.
    const tous = toutesLesExercices();
    const trouve = (motif, groupe) => (tous.find(e => motif.test(e.nom)) || tous.find(e => e.groupe === groupe) || tous[0]);
    const prog = (nom, liste) => ({ id: idUnique('prog'), nom, creeLe: Date.now(), maj: Date.now(),
      exercices: liste.map(([m, g, poids, reps]) => ({ exerciceId: trouve(m, g).id, series: [1, 2, 3].map(() => ({ poids, reps, technique: null })), supersetSuivant: false })) });
    musculationProgrammes = [
      prog('Push', [[/^D[ée]velopp[ée] couch[ée]/i, 'pectoraux', 70, 8], [/militaire/i, 'epaules', 40, 8], [/inclin/i, 'pectoraux', 26, 10], [/l[ée]vées? lat[ée]rales?/i, 'epaules', 10, 12], [/triceps/i, 'triceps', 25, 12]]),
      prog('Pull', [[/^Tractions?/i, 'dos', 0, 8], [/rowing/i, 'dos', 60, 10], [/tirage vertical/i, 'dos', 55, 10], [/curl/i, 'biceps', 14, 10], [/face pull|oiseau/i, 'epaules', 20, 15]]),
      prog('Jambes', [[/^squat/i, 'quadriceps', 90, 6], [/soulev[ée] de terre roumain|jambes tendues/i, 'ischios', 80, 8], [/presse/i, 'quadriceps', 160, 10], [/leg curl|ischio/i, 'ischios', 40, 12], [/mollets/i, 'mollets', 60, 15]])
    ];
    sauvegarderProgrammes();
    musculationHistorique = [];
    for (let k = N; k >= 1; k--) {
      const jourSemaine = k % 7; if (![1, 3, 6].includes(jourSemaine)) continue;
      const p = musculationProgrammes[[1, 3, 6].indexOf(jourSemaine)];
      const d = shiftDate(t, -k), debut = new Date(d + 'T18:30:00').getTime(), duree = Math.round(R(52, 74));
      const progres = 1 + (N - k) / N * 0.08;
      const entree = { id: idUnique('hist'), programmeId: p.id, programmeNom: p.nom, date: d, debut, fin: debut + duree * 60000, dureeMin: duree, notes: '', maj: debut,
        exercices: p.exercices.map(e => ({ exerciceId: e.exerciceId, nom: (tous.find(x => x.id === e.exerciceId) || {}).nom,
          series: e.series.map((s, i) => ({ poids: Math.round((s.poids || 0) * progres / 2.5) * 2.5, reps: s.reps - (i === 2 ? 1 : 0), fait: true })), supersetSuivant: false })) };
      musculationHistorique.unshift(entree);
      const jour = getDay(d); jour.workouts.push({ type: 'musculation', time: duree, seriesFaites: 15, source: 'seance', nom: p.nom }); saveData(d);
    }
    sauvegarderHistorique();
    saveData();
    currentDate = t;
  }
  /* La barre d'onglets native (iOS 26 et plus) doit prévenir la page : un
     appui simulé sur « Progrès » doit afficher Progrès. Et elle ne doit
     prévenir la page que d'un vrai appui, jamais en écho de ce que la page
     lui demande : deux changements d'écran coup sur coup (comme au
     lancement d'une séance) faisaient se renvoyer la balle aux deux, sans
     fin. Sinon la compilation échoue (CAPTURE:erreur). */
  async function verifierOngletsNatifs() {
    if (typeof ONGLETS_NATIFS === 'undefined' || !ONGLETS_NATIFS) { console.log('CAPTURE:onglets-page (pas de barre native)'); return; }
    const pause = ms => new Promise(fin => setTimeout(fin, ms));
    const barre = window.AppNatif.Onglets;
    allerA('repas');
    await barre.simulerToucher({ nom: 'stats' });
    await pause(1500);
    if (ecranActif === 'stats') console.log('CAPTURE:onglets-ok');
    else console.log('CAPTURE:erreur la barre native ne prévient pas la page (écran affiché : ' + ecranActif + ')');
    // Deux changements d'écran demandés par la page, coup sur coup.
    let changements = 0;
    const allerAPage = window.allerA;
    window.allerA = function () { changements++; return allerAPage.apply(this, arguments); };
    try { allerA('seance'); allerA('repas'); await pause(3000); } finally { window.allerA = allerAPage; }
    const etat = await barre.etat();
    if (changements > 2 || ecranActif !== 'repas' || etat.onglet !== 'repas' || etat.page !== 'repas') {
      console.log('CAPTURE:erreur la barre et la page se renvoient la balle (' + changements + " changements d'écran au lieu de 2 ; page : "
        + ecranActif + ', onglet de la barre : ' + etat.onglet + ', onglet où est la page : ' + etat.page + ')');
    } else console.log('CAPTURE:onglets-sans-boucle');
    allerA('repas');
  }
  /* Les miniatures animées des exercices, quand la version embarquée de l'appli web les a : dans la bibliothèque, la
     boucle d'un exercice à l'écran doit se mettre à jouer (fichier de l'app lu par morceaux, lecture sans geste de
     l'utilisateur), et les images fixes s'afficher. Vérifié après le dernier écran, pour ne rien changer au minutage
     des captures. Sinon la compilation échoue (CAPTURE:erreur). Appareil réglé sur « réduire les animations » :
     l'appli ne lance pas les boucles, c'est dit (CAPTURE:miniatures-fixes). */
  async function verifierMiniatures() {
    if (typeof animationVignette3D !== 'function') { console.log('CAPTURE:miniatures-absentes (version sans miniatures animées)'); return; }
    const pause = ms => new Promise(fin => setTimeout(fin, ms));
    fermerFenetres();
    allerA('seance'); ouvrirBibliotheque();
    const debut = Date.now(), liste = () => document.getElementById('picker-liste-exercices'), animees = vignettes3DAnimees();
    let videos = [];
    if (!animees) await pause(1500);
    while (animees && Date.now() - debut < 20000) {
      videos = [...liste().querySelectorAll('video.vignette-video')];
      if (videos.some(v => v.classList.contains('prete'))) break;
      await pause(250);
    }
    const imgs = [...liste().querySelectorAll('img.vignette-3d')];
    const bilan = { apres_ms: Date.now() - debut, posees: videos.length, jouent: videos.filter(v => v.classList.contains('prete')).length,
      sources: videos.slice(0, 2).map(v => v.getAttribute('src')), erreurs: videos.map(v => v.error && v.error.code).filter(Boolean),
      images: imgs.length, images_chargees: imgs.filter(i => i.complete && i.naturalWidth > 0).length, mouvement_reduit: !vignettes3DAnimees() };
    fermerFenetres();
    const fautes = [];
    if (!bilan.images_chargees) fautes.push("aucune image fixe ne s'affiche");
    if (!bilan.mouvement_reduit && !bilan.jouent) fautes.push("aucune boucle ne joue");
    console.log((fautes.length ? 'CAPTURE:erreur les miniatures des exercices : ' + fautes.join(' ; ') + ' ' : bilan.mouvement_reduit ? 'CAPTURE:miniatures-fixes ' : 'CAPTURE:miniatures-ok ') + JSON.stringify(bilan));
  }
  // Captures pilotées de l'extérieur (scripts/captures-ios.js de mon-coach) : les
  // données et les écrans sont exposés, la boucle automatique ne tourne pas.
  window.__demo = { remplirDemo, ECRANS, MONTRER, fermerFenetres, verifierMiniatures };
  if (window.__captureManuel) return;
  window.addEventListener('load', () => setTimeout(async () => {
    // Thème « auto » : l'app suit le mode clair ou sombre du simulateur.
    try { connexionObligatoire = false; fermerFenetres(); remplirDemo(); appliquerTheme('auto'); } catch (e) { console.log('CAPTURE:erreur ' + e.message); }
    try { await verifierOngletsNatifs(); } catch (e) { console.log('CAPTURE:erreur onglets natifs : ' + e.message); }
    // Le scanner de codes-barres de l'app répond (pas de caméra dans le simulateur).
    try { const r = await window.AppNatif.Scanner.etat(); console.log('CAPTURE:scanner-ok (caméra : ' + !!(r && r.camera) + ')'); }
    catch (e) { console.log('CAPTURE:erreur le scanner de l\'app ne répond pas : ' + e.message); }
    let i = 0;
    (function suivant() {
      if (i >= ECRANS.length) {
        verifierMiniatures().catch(e => console.log('CAPTURE:erreur les miniatures des exercices : ' + e.message)).then(() => console.log('CAPTURE:fin'));
        return;
      }
      const ecran = ECRANS[i++], debut = Date.now(), atlas = /^atlas/.test(ecran);
      let pret = null;
      try {
        fermerFenetres();
        if (MONTRER[ecran]) pret = Promise.resolve(MONTRER[ecran]()).catch(e => console.log('CAPTURE:erreur ' + e.message));
        else { allerA(ecran); if (ecran === 'repas') renderApp(); }
        window.scrollTo(0, 0);
      } catch (e) { console.log('CAPTURE:erreur ' + e.message); }
      // 24 s par écran : la capture se fait à l'annonce (le simulateur met
      // parfois 10 s à photographier), ou au minutage si le journal se tait.
      // L'annonce attend que l'écran soit vraiment peint (polices chargées,
      // deux images rendues) : une capture prise avant montrait une page blanche.
      // L'atlas se charge puis se dessine : son annonce attend qu'il soit vérifié (15 s au plus), et l'écran suivant
      // vient 24 s après le début de celui-ci, pour rester dans le minutage de la capture — mais jamais avant que
      // l'atlas ait rendu son verdict (75 s au plus : une mesure refaite sur une machine qui cale prend ce temps-là ;
      // passer à l'écran suivant refermerait l'atlas sous la mesure).
      setTimeout(() => {
        const peint = () => new Promise(fin => requestAnimationFrame(() => requestAnimationFrame(fin)));
        const borne = ms => (atlas && pret ? Promise.race([pret, new Promise(fin => setTimeout(fin, ms))]) : Promise.resolve());
        borne(15000).then(() => document.fonts && document.fonts.ready).then(peint).then(() => {
          console.log('CAPTURE:' + ecran);
          borne(75000).then(() => setTimeout(suivant, atlas ? Math.max(3000, 24000 - (Date.now() - debut)) : 22200));
        });
      }, 1800);
    })();
  }, 3500));
})();
