/// 📋 **L'ordine dei pezzi di Oggi** — `plan_interfaccia.md` I2, 19/11/2026.
///
/// ══ 🔑 PERCHÉ È UNA FUNZIONE PURA, FUORI DALLA SCHERMATA ══════════════════
///
/// L'ordine di Oggi porta **tre regole del committente**, e ognuna è stata
/// rotta almeno una volta:
///
/// 1. 🔒 *«per gli utenti non abbonati le cards vanno riarrangiate in modo che
///    quelle visibili siano le prime»* (08/09/2026) — o l'app si presenta come
///    un muro di cose sfumate;
/// 2. ⚖️ «Com'è fatto» **subito sotto il peso** (30/08/2026): è la stessa
///    domanda guardata più a fondo;
/// 3. 🏅 le medaglie **sopra il consiglio** (3b-A.8.3).
///
/// 💡 Scritto qui come un elenco di nomi, l'ordine si **verifica con un test
/// che non monta niente**: `test/oggi_ordine_test.dart`. ⛔ Dentro la
/// schermata, controllarlo voleva dire costruire Oggi con una ventina di
/// provider finti — e un test così costoso non lo scrive nessuno.
library;

/// Un pezzo della pagina Oggi, sotto la testata.
enum PezzoDiOggi {
  titoloEnergia,
  calorie,
  bannerAbbonamento,
  bannerSalute,
  achievements,
  spunto,
  titoloAllenamento,
  allenamento,
  titoloAndamento,

  /// La tessera del sonno e quella dell'Effetto, affiancate.
  sonnoEdEffetto,

  /// HRV e battito, affiancati.
  cuore,
  peso,
  composizione,
  grafico,

  /// 🔒 Solo per chi non è abbonato: il titolo sopra le cose sfumate.
  titoloConLAbbonamento,
}

/// I pezzi di Oggi, nell'ordine in cui si mostrano.
///
/// | | Abbonato | Non abbonato |
/// |---|---|---|
/// | prima | energia, banner, medaglie, consiglio | energia, banner, medaglie |
/// | poi | allenamento, andamento | il suo andamento: peso e grafico |
/// | in fondo | — | **«Con l'abbonamento»**: tutto quello che è sfumato |
///
/// ⚠️ Per chi non è abbonato il peso **perde** «Com'è fatto» sotto di sé, ed è
/// il prezzo della regola 1: già prima del 19/11 la composizione scendeva in
/// fondo con le sfumate. Le due regole si scontrano solo lì, e vince la prima.
List<PezzoDiOggi> pezziDiOggi({required bool abbonato}) {
  const energia = [
    PezzoDiOggi.titoloEnergia,
    PezzoDiOggi.calorie,

    /*
     * 💳 **Sotto la card delle calorie, non sopra**: la card è l'unica cosa
     * completa che un non abbonato vede, e il banner deve arrivare **dopo** che
     * l'app ha già dato qualcosa. Sparisce da solo per gli abbonati.
     */
    PezzoDiOggi.bannerAbbonamento,
    PezzoDiOggi.bannerSalute,
    PezzoDiOggi.achievements,
  ];

  if (abbonato) {
    return const [
      ...energia,
      PezzoDiOggi.spunto,
      PezzoDiOggi.titoloAllenamento,
      PezzoDiOggi.allenamento,
      PezzoDiOggi.titoloAndamento,
      PezzoDiOggi.sonnoEdEffetto,
      PezzoDiOggi.cuore,
      PezzoDiOggi.peso,
      PezzoDiOggi.composizione,
      PezzoDiOggi.grafico,
    ];
  }

  return const [
    ...energia,
    PezzoDiOggi.titoloAndamento,
    PezzoDiOggi.peso,
    PezzoDiOggi.grafico,
    PezzoDiOggi.titoloConLAbbonamento,
    PezzoDiOggi.spunto,
    PezzoDiOggi.sonnoEdEffetto,
    PezzoDiOggi.cuore,
    PezzoDiOggi.composizione,
    PezzoDiOggi.allenamento,
  ];
}

/// I pezzi che per chi non è abbonato stanno **dietro il cancello**.
///
/// 💡 Sta qui e non nella schermata perché è la stessa conoscenza dell'ordine:
/// il test controlla che nessuno di questi venga prima di un pezzo libero.
const pezziSottoAbbonamento = {
  PezzoDiOggi.spunto,
  PezzoDiOggi.sonnoEdEffetto,
  PezzoDiOggi.cuore,
  PezzoDiOggi.composizione,
  PezzoDiOggi.allenamento,
};
