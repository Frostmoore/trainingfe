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

/// Quello che serve a `RigheDelleSerie` per lavorare — 3b-D.11.
///
/// ══ 🚨 PERCHE' UN MIXIN E NON DUE WIDGET ══════════════════════════════════
///
/// 📌 *«queste modifiche devono riguardare anche l'editor del trainer e quello
/// del server, mi pare ovvio. A che cazzo serve fare delle modifiche se poi non
/// sono ovunque»*.
///
/// ⛔ Gli editor sono **due** — quello dell'iscritto ([EsercizioInScrittura]) e
/// quello del trainer (`EsercizioDellaScheda`) — e tengono i dati in modo
/// diverso per ragioni loro. 💡 Quello che **non** deve essere diverso è come si
/// compilano le serie: stesso widget, stessa autocompilazione, stesse regole.
///
/// ⚠️ Due copie sarebbero divergute alla prima correzione, e la prima a
/// divergere sarebbe stata quella del trainer — che si prova meno.
mixin ConLeSerie {
  /// Le righe da compilare.
  ///
  /// ⚠️ Si chiama `righe` e **non `serie`** per una ragione precisa: nel modello
  /// del trainer `serie` è già un `int?` — *quante* serie, il campo vecchio. Due
  /// cose diverse con lo stesso nome sono un errore che il compilatore trova e
  /// un lettore no.
  List<SerieInScrittura> get righe;

  CaricoDellEsercizio get carico;

  set carico(CaricoDellEsercizio valore);

  /// Riempie le righe **che nessuno ha ancora toccato** copiando la prima.
  ///
  /// 📌 *«Quando compilo la prima si devono autocompilare anche le altre sotto
  /// (ovviamente devo poterle modificare)»*.
  ///
  /// ⚠️ **La parentesi è la specifica vera**: «devo poterle modificare» vuol
  /// dire che una riga già toccata **non si tocca più**. 🚨 Senza quella
  /// guardia, scrivere il peso della terza serie e poi correggere la prima
  /// cancellerebbe la correzione appena fatta.
  ///
  /// ⛔ **E «toccata» non vuol dire «piena»**: guardando il contenuto invece di
  /// chi l'ha scritto, il primo tasto della prima riga si copiava sotto e da
  /// quel momento le righe smettevano di ricevere il resto — vedi
  /// [SerieInScrittura.toccataAMano].
  ///
  /// 💡 Sta qui e non nelle due classi proprio perché la regola è sottile: due
  /// copie avrebbero perso la guardia una alla volta.
  void autocompila() {
    if (righe.length < 2) return;

    final prima = righe.first;

    for (final riga in righe.skip(1)) {
      // 🚨 `toccataAMano` e non `intatta`: vedi la nota lunga li'.
      if (riga.toccataAMano) continue;

      riga.ripetizioni.text = prima.ripetizioni.text;
      riga.carico.text = prima.carico.text;
      riga.recupero.text = prima.recupero.text;
    }
  }
}

/// Una riga di serie, mentre la si compila.
class SerieInScrittura {
  SerieInScrittura({String? ripetizioni, String? carico, String? recupero})
    : ripetizioni = TextEditingController(text: ripetizioni ?? ''),
      carico = TextEditingController(text: carico ?? ''),
      recupero = TextEditingController(text: recupero ?? '');

  /// Da una serie gia' scritta.
  ///
  /// 🚨 **Nasce gia' [toccataAMano]**, ed e' il caso che si dimentica: aprendo
  /// una scheda che esiste, le righe sotto le ha scritte **una persona**.
  /// ⛔ Correggendo la prima, l'autocompilazione le sovrascriverebbe tutte — e
  /// chi voleva cambiare il peso della prima serie si ritroverebbe le altre
  /// due riscritte senza aver toccato niente.
  factory SerieInScrittura.da(SeriePrevista s) =>
      SerieInScrittura(
          ripetizioni: s.ripetizioni?.toString(),
          carico: _numero(s.peso) ?? s.isoSec?.toString(),
          recupero: s.recuperoSec?.toString(),
        )
        ..toccataAMano = true;

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

  /// ⚠️ **Qualcuno ha scritto in QUESTA riga** — 3b-D.15, 25/08/2026.
  ///
  /// ══ 🚨 NON E' «E' VUOTA», E LA DIFFERENZA E' TUTTO ═══════════════════════
  ///
  /// ⛔ L'autocompilazione guardava se la riga fosse **vuota**, e il difetto si
  /// vedeva alla seconda cifra: scrivendo «12» nella prima riga, il **primo
  /// tasto** («1») si copiava sotto — e da quel momento le righe sotto non
  /// erano piu' vuote, quindi il «2» non arrivava piu'. Restavano a «1».
  ///
  /// 🚨 A schermo sembra che l'autocompilazione **non funzioni affatto**, ed e'
  /// peggio che se non ci fosse: lascia dei numeri sbagliati dove ci si aspetta
  /// quelli giusti, e chi salva non li rilegge uno per uno.
  ///
  /// 💡 Quello che conta non e' il contenuto: e' **chi l'ha scritto**. Una riga
  /// che ha solo ricevuto la copia resta disponibile per la prossima; una in
  /// cui una persona ha battuto un tasto non si tocca piu'.
  bool toccataAMano = false;

  /// ⚠️ Vuota davvero: nessuno dei tre campi ha niente dentro.
  ///
  /// 💡 Serve a **non mandare al server tre serie da niente** quando un
  /// esercizio e' appena stato aggiunto — non all'autocompilazione, che guarda
  /// [toccataAMano].
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
class EsercizioInScrittura with ConLeSerie {
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

  @override
  CaricoDellEsercizio carico;

  final List<SerieInScrittura> serie;

  /// 💡 Le righe si chiamano `serie` qui e `righe` nel mixin: qui non c'è
  /// nessun `int? serie` con cui confondersi, e cambiare nome a un campo usato
  /// in mezza schermata per una simmetria non sarebbe un miglioramento.
  @override
  List<SerieInScrittura> get righe => serie;

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
