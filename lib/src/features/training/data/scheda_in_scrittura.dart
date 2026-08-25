/// Lo stato di una scheda mentre la si scrive — 3b-D, 25/08/2026.
///
/// ══ 🚨 PERCHE' STA QUI E NON DENTRO LA SCHERMATA ══════════════════════════
///
/// ⛔ L'editor vecchio teneva le sue righe in una classe privata dentro il file
/// della schermata. Andava bene finché una riga erano cinque campi di testo.
///
/// 💡 Adesso c'è **della logica**: l'autocompilazione delle serie, il carico
/// che cambia forma, il JSON che si scrive in due formati. Roba che si prova
/// con un test invece che aprendo l'app, ma **solo se non vive dentro un
/// widget**.
library;

import 'package:flutter/widgets.dart';

import 'gruppo_muscolare.dart';
import 'serie_prevista.dart';

/// Una riga di serie, mentre la si compila.
class SerieInScrittura {
  SerieInScrittura({String? ripetizioni, String? carico, String? recupero})
    : ripetizioni = TextEditingController(text: ripetizioni ?? ''),
      carico = TextEditingController(text: carico ?? ''),
      recupero = TextEditingController(text: recupero ?? '');

  factory SerieInScrittura.da(SeriePrevista s) => SerieInScrittura(
    ripetizioni: s.ripetizioni?.toString(),
    carico: _numero(s.peso) ?? s.isoSec?.toString(),
    recupero: s.recuperoSec?.toString(),
  );

  /// ⚠️ **`40` e non `40.0`**: il campo lo legge una persona, e un peso intero
  /// scritto con lo zero dietro sembra una precisione che non c'è.
  static String? _numero(double? v) {
    if (v == null) return null;

    return v == v.roundToDouble() ? v.round().toString() : v.toString();
  }

  final TextEditingController ripetizioni;

  /// I chili **oppure** i secondi di isometria: quale dei due lo dice
  /// [EsercizioInScrittura.carico].
  ///
  /// 💡 Un campo solo e non due: sono la stessa colonna sullo schermo, e
  /// tenerne due vorrebbe dire ricordarsi di svuotare quello spento.
  final TextEditingController carico;

  final TextEditingController recupero;

  /// ⚠️ Una riga «intatta» è una che **nessuno ha ancora toccato**.
  ///
  /// 🚨 È la guardia dell'autocompilazione: si riempiono solo le righe intatte,
  /// perché sovrascrivere un numero appena scritto è il modo più veloce di far
  /// perdere il lavoro a chi sta compilando.
  bool get intatta =>
      ripetizioni.text.trim().isEmpty &&
      carico.text.trim().isEmpty &&
      recupero.text.trim().isEmpty;

  SeriePrevista versoIlDato(CaricoDellEsercizio carico) {
    final numero = double.tryParse(
      this.carico.text.trim().replaceAll(',', '.'),
    );

    return SeriePrevista(
      ripetizioni: int.tryParse(ripetizioni.text.trim()),
      peso: carico == CaricoDellEsercizio.peso ? numero : null,
      isoSec: carico == CaricoDellEsercizio.iso ? numero?.round() : null,
      recuperoSec: int.tryParse(recupero.text.trim()),
    );
  }

  void dispose() {
    ripetizioni.dispose();
    carico.dispose();
    recupero.dispose();
  }
}

/// Un esercizio, mentre lo si scrive.
class EsercizioInScrittura {
  EsercizioInScrittura({
    String? nome,
    String? note,
    this.exerciseId,
    this.muscoli,
    this.immagine,
    this.carico = CaricoDellEsercizio.peso,
    List<SerieInScrittura>? serie,
  }) : nome = TextEditingController(text: nome ?? ''),
       note = TextEditingController(text: note ?? ''),
       serie =
           serie ??
           /*
            * 📌 *«ogni esercizio deve partire di base con 3 serie»*.
            *
            * 💡 Tre e non una: chi apre l'editor si trova davanti la forma di
            * quello che sta per scrivere, invece di doverla costruire. ⚠️ E chi
            * ne vuole una sola ne toglie due, che e' un gesto piu' breve che
            * aggiungerne due.
            */
           List.generate(seriePredefinite, (_) => SerieInScrittura());

  /// Da un esercizio già scritto — **da qualunque formato arrivi**.
  ///
  /// 🚨 Passa da [serieDellEsercizio], quindi una scheda vecchia si apre
  /// nell'editor nuovo **già in righe**: è il *«le schede già esistenti
  /// ricalchino questa nuova impostazione»* del committente, e succede qui.
  factory EsercizioInScrittura.da(Map<String, dynamic> j) =>
      EsercizioInScrittura(
        nome:
            j['name']?.toString() ??
            (j['exercise'] as Map?)?['name']?.toString(),
        note: j['notes']?.toString(),
        exerciseId:
            (j['exercise_id'] as num?)?.toInt() ??
            ((j['exercise'] as Map?)?['id'] as num?)?.toInt(),
        muscoli: muscoliDaJson(j),
        immagine: j['immagine']?.toString(),
        carico: CaricoDellEsercizio.da(j['carico']?.toString()),
        serie: [
          for (final s in serieDellEsercizio(j)) SerieInScrittura.da(s),
        ],
      );

  static const seriePredefinite = 3;

  final TextEditingController nome;
  final TextEditingController note;

  /// L'id nel catalogo, quando il nome è stato scelto dall'elenco.
  ///
  /// 🚨 **È il pezzo che conta più del nome**: con questo `pesiDellaScheda`
  /// trova i muscoli **nel catalogo**, e la figura in fondo alla scheda si
  /// accende senza che i muscoli siano scritti dentro la scheda.
  int? exerciseId;

  MuscoliScelti? muscoli;

  /// Il percorso **relativo** dell'immagine (`foto/esercizi/…`).
  String? immagine;

  CaricoDellEsercizio carico;

  final List<SerieInScrittura> serie;

  /// Copia la prima riga su quelle **ancora intatte**.
  ///
  /// 📌 *«Quando compilo la prima si devono autocompilare anche le altre sotto
  /// (ovviamente devo poterle modificare)»*.
  ///
  /// ⚠️ La parentesi del committente è la specifica vera: «devo poterle
  /// modificare» vuol dire che una riga già toccata **non si tocca più**. 🚨
  /// Senza quella guardia, scrivere il peso della terza serie e poi correggere
  /// la prima cancellerebbe la correzione appena fatta.
  void autocompila() {
    if (serie.length < 2) return;

    final prima = serie.first;

    for (final riga in serie.skip(1)) {
      if (!riga.intatta) continue;

      riga.ripetizioni.text = prima.ripetizioni.text;
      riga.carico.text = prima.carico.text;
      riga.recupero.text = prima.recupero.text;
    }
  }

  Map<String, dynamic> versoIlDato() => esercizioInJson(
    nome: nome.text.trim(),
    serie: [for (final s in serie) s.versoIlDato(carico)],
    carico: carico,
    exerciseId: exerciseId,
    note: note.text.trim(),
    immagine: immagine,
    muscoli: muscoliInJson(muscoli),
  );

  void dispose() {
    nome.dispose();
    note.dispose();

    for (final s in serie) {
      s.dispose();
    }
  }
}

/// I muscoli scritti dentro un esercizio, se ci sono.
///
/// ⚠️ **Tre stati, non due** — la stessa regola di `muscoliInJson`: `null` vuol
/// dire «nessuno l'ha deciso», un elenco vuoto vuol dire «questo esercizio
/// isola davvero».
MuscoliScelti? muscoliDaJson(Map<String, dynamic> j) {
  final primario = GruppoMuscolare.da(
    j['muscle_group']?.toString() ??
        (j['exercise'] as Map?)?['muscle_group']?.toString(),
  );

  final secondari = j['secondary_muscles'] as List?;

  if (primario == null && secondari == null) return null;

  return (
    primario: primario,
    secondari: [
      for (final m in secondari ?? const []) ?GruppoMuscolare.da(m?.toString()),
    ],
  );
}
