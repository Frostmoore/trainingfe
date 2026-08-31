/// Quanto costa, in gettoni, ogni funzione che si chiede a mano — 3b-AE.
///
/// ══ 📌 PERCHÉ IL PREZZO STA SUL PULSANTE ══════════════════════════════════
///
/// 📌 Il committente, da 3b-I: *«il tasto deve avere scritto che costa 1
/// gettone»*.
///
/// 🚨 **È l'unico posto onesto per scriverlo**: chi tocca sta spendendo, e
/// leggerlo *dopo* nel saldo è il modo per non fidarsi più di nessun altro
/// pulsante dell'app.
///
/// ⛔ Fino al 30/08 nel diario non c'era, e non era una svista: la stima di un
/// alimento **non costava un gettone**, passava dalla quota inclusa. Da 3b-AE
/// costa, e il pulsante deve dirlo.
///
/// ══ 🚨 QUESTI NUMERI SONO UNA COPIA, E VA SAPUTO ══════════════════════════
///
/// La fonte di verità è `AiFeature::costoInGettoni()` sul server, ed è lui che
/// scala. ⚠️ Qui c'è una copia per poterla **scrivere sul pulsante prima** di
/// chiamare: chiedere al server quanto costa, per poi chiedergli di farlo,
/// sarebbe una chiamata in più per ogni schermata che mostra un prezzo.
///
/// ⛔ **Se cambiano di là, cambiano qui.** Un prezzo che mente su un pulsante è
/// peggio di un prezzo assente: chi legge «1 gettone» e ne vede sparire dieci
/// non torna a leggere l'etichetta, smette di fidarsi dell'app.
///
/// 💡 Il verso in cui sbagliare, se un giorno diverge, è **verso l'alto**: dire
/// che costa più di quanto costa delude in modo recuperabile, dire che costa
/// meno è una bugia sul prezzo.
library;

/// Le funzioni che si pagano toccando qualcosa.
enum AiACosa {
  /// La stima di un alimento scritto a mano.
  cibo(1),

  /// La stima da una foto del piatto.
  ///
  /// 💡 **Dieci e non sette**: sette è il costo *misurato* (una foto costa 7,1
  /// volte una chiamata ordinaria), dieci è il **prezzo**. La differenza è
  /// margine, ed è una decisione commerciale — non un errore di conversione.
  foto(10),

  /// L'analisi della progressione di una scheda, chiesta col pulsante.
  ///
  /// ⛔ Quella **automatica** non costa niente: parte dopo un allenamento ed è
  /// compresa nell'abbonamento (3b-AB).
  scheda(1),

  /// «Rigenera» sul consiglio del giorno.
  ///
  /// ⛔ I tre consigli automatici del giorno non costano gettoni.
  consiglio(1),

  /// L'import di una scheda o di un piano da PDF.
  ///
  /// 🚨 **Sempre a gettoni, abbonato o no** — U.6: 📌 *«L'import dei pdf costa
  /// SEMPRE 50 gettoni»*.
  pdf(50);

  const AiACosa(this.gettoni);

  final int gettoni;
}

/// «1 gettone», «10 gettoni». Da mettere dopo un `·` sul pulsante.
///
/// 💡 Il singolare esiste perché *«1 gettoni»* su un pulsante è la cosa che chi
/// legge nota prima del prezzo.
String costoDi(AiACosa cosa) =>
    '${cosa.gettoni} ${cosa.gettoni == 1 ? 'gettone' : 'gettoni'}';
