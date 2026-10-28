/* Compilation de vérification uniquement (preparer-www.mjs --capture) : ce
   fichier n'est jamais dans l'app livrée. Il remplit l'appli de données de
   démonstration (6 semaines de repas, poids, pas, eau, cardio et muscu), puis
   passe d'écran en écran. Le journal annonce chaque écran (« CAPTURE:repas »…)
   pour que la compilation dans le cloud prenne la capture au bon moment. */
(function () {
  const ECRANS = ['repas', 'seance', 'stats', 'reglages'];
  function fermerFenetres() {
    document.querySelectorAll('.modal.show, .feuille.show').forEach(m => m.classList.remove('show'));
    document.body.classList.remove('couche-ouverte');
  }
  function remplirDemo() {
    const t = todayStr();
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
  window.addEventListener('load', () => setTimeout(() => {
    // Thème « auto » : l'app suit le mode clair ou sombre du simulateur.
    try { connexionObligatoire = false; fermerFenetres(); remplirDemo(); appliquerTheme('auto'); } catch (e) { console.log('CAPTURE:erreur ' + e.message); }
    let i = 0;
    (function suivant() {
      if (i >= ECRANS.length) { console.log('CAPTURE:fin'); return; }
      const ecran = ECRANS[i++];
      try { fermerFenetres(); allerA(ecran); if (ecran === 'repas') renderApp(); window.scrollTo(0, 0); } catch (e) { console.log('CAPTURE:erreur ' + e.message); }
      setTimeout(() => { console.log('CAPTURE:' + ecran); setTimeout(suivant, 3000); }, 1800);
    })();
  }, 3500));
})();
