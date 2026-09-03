/// Dalla bozza del server al modulo che si compila a mano — Parte K, K3.
///
/// ══ 🚨 PERCHE' NON C'E' UN EDITOR DELL'IMPORT ═════════════════════════════
///
/// 📌 Il committente, il 03/09/2026: *«si deve poter modificare tutto quello che
/// è stato generato dall'ai nello stesso modo in cui si creerebbe una scheda o
/// un piano alimentare»*.
///
/// ⛔ La strada corta sarebbe una schermata di revisione con i suoi campi — ed è
/// quella che c'era (`RevisionePianoImportato`, 607 righe). 🚨 Ma due editor
/// dello stesso oggetto **divergono**: si aggiunge un campo al compositore, e
/// l'import continua a non averlo. Nessun errore, nessun test rosso; solo una
/// funzione che invecchia da sola.
///
/// 💡 Quindi la bozza non apre una schermata sua: diventa **il modulo vero**,
/// già compilato. Questo file è l'unico pezzo di codice che serve a farlo.
library;

import '../../nutrition/data/piano_alimentare.dart';
import '../../training/data/scheda_allenamento.dart';

/// La scheda trascritta, divisa nei suoi giorni.
///
/// ══ 🚨 IL RAGGRUPPAMENTO PER GIORNO SI FA QUI, E SOLO QUI ═════════════════
///
/// Il modello risponde con un elenco **piatto** di esercizi, ognuno con il suo
/// `day`. ⛔ Il compositore invece ragiona per giorni, e non deve sapere niente
/// di come è fatta una risposta dell'AI.
///
/// ⚠️ **I giorni si contano dal massimo `day`, non dai valori distinti**: se il
/// modello marca gli esercizi come 1 e 3 — perché il giorno 2 era illeggibile —
/// i giorni sono **tre**, e il secondo è vuoto. 🚨 Contando i valori distinti se
/// ne otterrebbero due, e il terzo giorno diventerebbe silenziosamente il
/// secondo: una scheda che sembra completa e ha il mercoledì al posto del
/// martedì.
SchedaAllenamento schedaDallaBozza(Map<String, dynamic> bozza) {
  final righe = ((bozza['exercises'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => e.cast<String, dynamic>())
      .toList();

  final nomiDeiGiorni = ((bozza['day_names'] as List?) ?? const [])
      .map((e) => e.toString())
      .toList();

  var quanti = 1;

  for (final riga in righe) {
    final giorno = (riga['day'] as num?)?.toInt() ?? 1;

    if (giorno > quanti) quanti = giorno;
  }

  final giorni = <GiornoDellaScheda>[];

  for (var g = 1; g <= quanti; g++) {
    /*
     * ⚠️ **Il nome del giorno solo se il modello l'ha letto sul foglio.**
     * Inventare «Giorno 2» dove non c'era scritto niente vorrebbe dire mettere
     * in bocca al documento una cosa che non dice — ed è esattamente ciò che
     * questa revisione esiste per impedire.
     */
    final nome = g <= nomiDeiGiorni.length ? nomiDeiGiorni[g - 1].trim() : '';

    giorni.add(
      GiornoDellaScheda(
        nome: nome.isEmpty ? null : nome,
        esercizi: [
          for (final riga in righe)
            if (((riga['day'] as num?)?.toInt() ?? 1) == g)
              EsercizioDellaScheda.fromJson(riga),
        ],
      ),
    );
  }

  final nome = bozza['name']?.toString().trim() ?? '';

  return SchedaAllenamento(
    nome: nome.isEmpty ? 'Scheda importata' : nome,

    /*
     * ⛔ **Le note del modello non diventano le note della scheda.** Sono il
     * suo referto — «questa riga era illeggibile» — non una prescrizione, e
     * copiarle qui le farebbe leggere per mesi come se le avesse scritte il
     * trainer. 💡 Vanno in cima alla revisione, fra i dubbi.
     */
    giorni: giorni,
  );
}

/// Il piano trascritto, nella forma del compositore.
///
/// ⚠️ **I grammi mancanti restano vuoti.** Se il modello ha letto «un
/// cucchiaio» e non un peso, il campo numerico non si riempie con una
/// conversione inventata: 🚨 sarebbe esattamente il tipo di errore che questa
/// revisione esiste per intercettare — un numero plausibile che nessuno ha
/// scritto.
PianoAlimentare pianoDallaBozza(Map<String, dynamic> bozza) {
  final giorni = <GiornoDelPiano>[];

  for (final g in (bozza['giorni'] as List?) ?? const []) {
    final giorno = (g as Map).cast<String, dynamic>();
    final nome = giorno['nome']?.toString().trim() ?? '';

    giorni.add(
      GiornoDelPiano(
        nome: nome.isEmpty ? null : nome,
        pasti: [
          for (final p in (giorno['pasti'] as List?) ?? const [])
            _pastoDa((p as Map).cast<String, dynamic>()),
        ],
      ),
    );
  }

  final nome = bozza['nome']?.toString().trim() ?? '';

  return PianoAlimentare(
    nome: nome.isEmpty ? 'Piano importato' : nome,

    /*
     * 🚨 **`TipoPiano.piano` e non `consigli`**: un documento firmato da un
     * professionista è un piano vero, con i suoi giorni e i suoi grammi. ⛔ Il
     * tipo `consigli` è un elenco di alimenti senza giorni, e il server rifiuta
     * con 422 un `consigli` che porti giorni — cioè tutti quelli importati.
     */
    tipo: TipoPiano.piano,
    giorni: giorni,
  );
}

/// Un pasto e **le sue alternative**.
///
/// ══ 🚨 LE ALTERNATIVE SONO ALTERNATIVE, NON PASTI IN PIU' ═════════════════
///
/// ⛔ Fino al 03/09/2026 lo schema del modello non aveva **nessun posto** dove
/// metterle, e su un documento vero il modello faceva l'unica cosa che poteva:
/// le trascriveva come **pasti normali**. Una giornata da cinque pasti ne
/// mostrava otto, e chi la legge crede di doverli mangiare tutti.
///
/// 💡 Adesso arrivano dentro il pasto che sostituiscono, ed è lì che vanno:
/// `PastoDelPiano.alternative` esiste da D2, e la scheda «Dal piano» le mostra
/// con «oppure» accanto a quello che rimpiazzano.
PastoDelPiano _pastoDa(Map<String, dynamic> dati) {
  final orario = dati['orario']?.toString().trim() ?? '';
  final tipo = dati['tipo']?.toString() ?? 'snack';

  return PastoDelPiano(
    pasto: tipo,

    /*
     * 💡 **L'orario diventa il titolo del pasto.** Il compositore non ha un
     * campo per l'ora — un piano composto a mano non ne ha bisogno — e buttarla
     * via perderebbe un'informazione che sul foglio c'era: «Spuntino · 16:30»
     * non è lo stesso di «Spuntino».
     */
    titolo: orario.isEmpty ? null : orario,
    alimenti: [
      for (final a in (dati['alimenti'] as List?) ?? const [])
        _alimentoDa((a as Map).cast<String, dynamic>()),
    ],
    alternative: [
      for (final v in (dati['alternative'] as List?) ?? const [])
        _alternativaDa((v as Map).cast<String, dynamic>(), tipo),
    ],
  );
}

/// ⚠️ **Un'alternativa non ha alternative sue**, e non è una semplificazione:
/// l'alternativa di un'alternativa non esiste su nessun foglio, e lo schema del
/// modello si ferma a un livello per lo stesso motivo.
PastoDelPiano _alternativaDa(Map<String, dynamic> dati, String tipoDelPasto) =>
    PastoDelPiano(
      /*
   * 🚨 **Il `pasto` è quello del principale**, non quello scritto
   * sull'alternativa. «Colazione alternativa» non è un tipo di pasto: i tipi
   * sono quattro (`breakfast`, `lunch`, `dinner`, `snack`), e inventarne un
   * quinto romperebbe tutto ciò che li legge — a partire dal diario, che sul
   * tipo decide in quale pasto della giornata finisce quello che si registra.
   *
   * 💡 Chi sceglie un'alternativa la mangia **al posto** del principale, quindi
   * il tipo giusto è esattamente quello.
   */
      pasto: tipoDelPasto,

      // 💡 Il nome che il documento le dà, che è l'unica cosa che la distingue.
      titolo: dati['tipo']?.toString(),
      alimenti: [
        for (final a in (dati['alimenti'] as List?) ?? const [])
          _alimentoDa((a as Map).cast<String, dynamic>()),
      ],
    );

AlimentoDelPiano _alimentoDa(Map<String, dynamic> dati) => AlimentoDelPiano(
      descrizione: dati['descrizione']?.toString() ?? '',
      grammi: (dati['grammi'] as num?)?.toDouble(),

      /*
   * 🚨 **`origineValori: 'ai'`, e non è un'etichetta di comodo.** Dice che quei
   * numeri non li ha scritti una persona: è il campo su cui l'app decide se un
   * valore si può sovrascrivere con una stima, e trattarli come `manual`
   * vorrebbe dire proteggere per sempre una cifra letta male da una fotografia.
   */
      origineValori: 'ai',
    );
