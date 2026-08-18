/// L'unica misura delle foto dell'app — N9.1.
///
/// ── 🚨 Una sola, e di proposito ────────────────────────────────────────────
///
/// Fino alla `v7.3.0` la misura era una anche prima, ma **tarata sull'AI**
/// (1600 px sul lato lungo): le foto di progresso ne pagavano il pegno venendo
/// salvate a quattro volte i pixel che servono a guardarle, per sempre, sul
/// disco e nel backup di ogni persona.
///
/// ⚠️ La lezione non è «serviva una misura per uso»: è che **la misura non era
/// stata scelta per tutti gli usi**. Due misure sono l'inizio di quattro, e
/// quattro divergono. Se un giorno servisse più grande, si cambia [lato] qui e
/// vale ovunque.
///
/// ── Perché 1080, e perché quadrata ─────────────────────────────────────────
///
/// 💡 **1080** è la risoluzione di uno schermo di telefono: più pixel non li
/// vedrebbe nessuno, e si pagherebbero per sempre in spazio e in banda.
///
/// 💡 **Quadrata** perché le foto di progresso si guardano **in fila, per
/// confrontarle nel tempo**: proporzioni diverse rendono il confronto
/// illeggibile proprio quando serve.
///
/// 🚨 **Vale anche per le foto che vanno al modello.** I token immagine
/// crescono con l'**area**, quindi 1080² contro i 1568² del server è **meno
/// della metà** del costo. L'obiezione «un piatto ritagliato è un piatto di cui
/// il modello non vede metà» cade grazie all'overlay della fotocamera: se
/// inquadri dentro il quadrato, quello che vedi è quello che parte. Il problema
/// esisteva solo finché il ritaglio era cieco.
class FormatoFoto {
  const FormatoFoto._();

  /// Il lato del quadrato, in pixel.
  static const int lato = 1080;

  /// La qualità JPEG.
  ///
  /// 💡 85 è il punto oltre il quale il file cresce senza che l'occhio veda
  /// niente di più. Sotto l'80 cominciano a vedersi i blocchi sulle sfumature —
  /// che nella foto di una schiena è esattamente dove si guarda.
  static const int qualita = 85;
}
