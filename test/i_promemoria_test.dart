import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:training_companion/src/core/notifications/catalogo.dart';
import 'package:training_companion/src/core/notifications/i_promemoria.dart';
import 'package:training_companion/src/core/notifications/preferenze_dei_promemoria.dart';

/// ⏰ **I promemoria locali** — voce 62, 27/09/2026.
///
/// ══ 📌 COSA SI PROVA QUI, E COSA NO ═══════════════════════════════════════
///
/// 🔑 Si provano **le regole**: quando un promemoria serve, quando no, e a che
/// istante viene messo. ⛔ Non si prova che il telefono lo faccia suonare: quello
/// e' `flutter_local_notifications`, ed e' roba di sistema.
///
/// 💡 Per questo `IPromemoria` prende le tre date da fuori
/// (`StatoDeiPromemoria`) invece di leggere il database: ⚖️ le regole si provano
/// con tre date scritte a mano, e una regola provata caso per caso e' una regola
/// che si puo' cambiare senza paura.
///
/// ══ ⚠️ PERCHE' UN FINTO PLUGIN E NON UN MOCK DI LIBRERIA ══════════════════
///
/// Il finto qui sotto **registra cosa gli e' stato chiesto**: id, titolo, corpo e
/// istante. 💡 Sono esattamente le quattro cose che decidono se un promemoria e'
/// giusto, e guardarle e' piu' diretto che verificare una chiamata.
void main() {
  setUpAll(() {
    /*
     * 🕐 **Il fuso serve, e senza questo il test sbaglia in modo confuso.**
     *
     * `IPromemoria` costruisce `tz.TZDateTime` su `tz.local`, e senza
     * `initializeTimeZones()` quello lancia `LocationNotFoundException` — la
     * stessa trappola descritta in `notifications.dart`, che in produzione si
     * presentava alla prima serie registrata invece che all'avvio.
     */
    tzdata.initializeTimeZones();
  });

  /// 🏗️ Il programmatore, con un plugin finto che scrive quello che gli chiedi.
  (IPromemoria, _PluginFinto) conIlFinto() {
    final finto = _PluginFinto();

    return (IPromemoria(finto), finto);
  }

  group('promemoria dell allenamento', () {
    /// ✅ Chi non si allena da giorni lo riceve, e **da domani in poi** se l'ora
    /// di oggi e' passata.
    test('chi non si allena lo riceve per i prossimi giorni', () async {
      final (promemoria, finto) = conIlFinto();

      await promemoria.riprogramma(
        stato: StatoDeiPromemoria(
          ultimoAllenamento: DateTime(2026, 9, 20),
        ),
        preferenze: const PreferenzeDeiPromemoria(
          diario: false,
          misure: false,
        ),
        adesso: DateTime(2026, 9, 27, 10),
      );

      final suoi = finto.programmati
          .where((p) => p.id >= IPromemoria.idAllenamento && p.id < IPromemoria.idDiario)
          .toList();

      expect(
        suoi.length,
        IPromemoria.giorniAvanti,
        reason:
            '🔑 Si programmano ${IPromemoria.giorniAvanti} giorni avanti: e la '
            'parte che fa funzionare «sono tre giorni che non ti alleni» per chi '
            "non apre l'app.",
      );

      /* ⏰ Alle 10 del mattino, il primo utile e' oggi alle 18. */
      expect(suoi.first.quando.day, 27);
      expect(suoi.first.quando.hour, 18);
    });

    /// 🚨 **Chi si e' allenato oggi NON lo riceve oggi.**
    ///
    /// ⛔ E' il caso che rende il promemoria tollerabile: «ci alleniamo?» alle 18
    /// a chi ha finito alle 17 e' il genere di errore per cui si spengono tutte
    /// le notifiche dell'app.
    test('chi si e allenato oggi non lo riceve oggi', () async {
      final (promemoria, finto) = conIlFinto();

      await promemoria.riprogramma(
        stato: StatoDeiPromemoria(
          ultimoAllenamento: DateTime(2026, 9, 27, 17),
        ),
        preferenze: const PreferenzeDeiPromemoria(diario: false, misure: false),
        adesso: DateTime(2026, 9, 27, 10),
      );

      final oggi = finto.programmati.where(
        (p) => p.id == IPromemoria.idAllenamento && p.quando.day == 27,
      );

      expect(
        oggi,
        isEmpty,
        reason:
            "🚨 Programmato per oggi a chi si e' allenato oggi. ⛔ E' una notifica "
            'che dice il falso, e una notifica che dice il falso la si spegne.',
      );

      /* 💡 Ma domani si: da qui non si puo' sapere se domani si allenera'. */
      expect(
        finto.programmati.any(
          (p) => p.id == IPromemoria.idAllenamento + 1 && p.quando.day == 28,
        ),
        isTrue,
      );
    });

    /// ✍️ **Il testo dice il numero giusto di giorni.**
    ///
    /// ⚖️ Non e' un vezzo: «sono cinque giorni che non ti alleni» a chi si e'
    /// allenato ieri e' falso. 🔑 E il numero e' quello del giorno in cui la
    /// notifica **suonera'**, non di oggi.
    test('il testo conta i giorni del giorno in cui suona', () async {
      final (promemoria, finto) = conIlFinto();

      await promemoria.riprogramma(
        stato: StatoDeiPromemoria(ultimoAllenamento: DateTime(2026, 9, 25)),
        preferenze: const PreferenzeDeiPromemoria(diario: false, misure: false),
        adesso: DateTime(2026, 9, 27, 10),
      );

      final oggi = finto.programmati.firstWhere(
        (p) => p.id == IPromemoria.idAllenamento,
      );
      final fraTreGiorni = finto.programmati.firstWhere(
        (p) => p.id == IPromemoria.idAllenamento + 3,
      );

      expect(oggi.corpo, contains('Due giorni'));

      expect(
        fraTreGiorni.corpo,
        contains('5 giorni'),
        reason:
            '🔑 Fra tre giorni saranno cinque dal 25. ⛔ Scrivendo i giorni di '
            'oggi, quella notifica direbbe «due» quando ne sono passati cinque.',
      );
    });

    /// ⛔ Spento vuol dire spento, e **subito**.
    test('spento non programma niente', () async {
      final (promemoria, finto) = conIlFinto();

      await promemoria.riprogramma(
        stato: const StatoDeiPromemoria(),
        preferenze: const PreferenzeDeiPromemoria(
          allenamento: false,
          diario: false,
          misure: false,
        ),
        adesso: DateTime(2026, 9, 27, 10),
      );

      expect(finto.programmati, isEmpty);

      expect(
        finto.cancellati,
        isNotEmpty,
        reason:
            '🚨 Deve cancellare comunque: ⛔ senza, un promemoria spento '
            'continuerebbe a suonare per una settimana — quelli programmati prima '
            'sono ancora in piedi.',
      );
    });
  });

  group('promemoria del diario', () {
    test('chi non ha segnato niente lo riceve stasera', () async {
      final (promemoria, finto) = conIlFinto();

      await promemoria.riprogramma(
        stato: StatoDeiPromemoria(ultimaVoceDiario: DateTime(2026, 9, 26, 20)),
        preferenze: const PreferenzeDeiPromemoria(
          allenamento: false,
          misure: false,
        ),
        adesso: DateTime(2026, 9, 27, 15),
      );

      final primo = finto.programmati.firstWhere(
        (p) => p.id == IPromemoria.idDiario,
      );

      expect(primo.quando.day, 27);
      expect(primo.quando.hour, 21);
    });

    test('chi ha segnato oggi non lo riceve oggi', () async {
      final (promemoria, finto) = conIlFinto();

      await promemoria.riprogramma(
        stato: StatoDeiPromemoria(ultimaVoceDiario: DateTime(2026, 9, 27, 13)),
        preferenze: const PreferenzeDeiPromemoria(
          allenamento: false,
          misure: false,
        ),
        adesso: DateTime(2026, 9, 27, 15),
      );

      expect(
        finto.programmati.any(
          (p) => p.id == IPromemoria.idDiario && p.quando.day == 27,
        ),
        isFalse,
      );
    });
  });

  group('promemoria delle misure', () {
    /// 📆 Nessuna misura: il prossimo giorno scelto.
    test('senza misure recenti va al giorno scelto', () async {
      final (promemoria, finto) = conIlFinto();

      /* 🗓️ Il 27/09/2026 e' una domenica: il lunedi' e' il giorno dopo. */
      await promemoria.riprogramma(
        stato: const StatoDeiPromemoria(),
        preferenze: const PreferenzeDeiPromemoria(
          allenamento: false,
          diario: false,
        ),
        adesso: DateTime(2026, 9, 27, 15),
      );

      final misure = finto.programmati.firstWhere(
        (p) => p.id == IPromemoria.idMisure,
      );

      expect(misure.quando.weekday, DateTime.monday);
      expect(misure.quando.hour, 9);
    });

    /// 🔑 **Chi si e' pesato di recente viene richiamato sette giorni dopo QUELLA
    /// pesata**, non al prossimo lunedi'.
    ///
    /// ⛔ Altrimenti chi si pesa il sabato riceve il richiamo due giorni dopo, e
    /// un richiamo settimanale che arriva ogni due giorni non e' settimanale.
    test('chi si e pesato di recente aspetta sette giorni da quella pesata', () async {
      final (promemoria, finto) = conIlFinto();

      await promemoria.riprogramma(
        stato: StatoDeiPromemoria(ultimaMisura: DateTime(2026, 9, 26)),
        preferenze: const PreferenzeDeiPromemoria(
          allenamento: false,
          diario: false,
        ),
        adesso: DateTime(2026, 9, 27, 15),
      );

      final misure = finto.programmati.firstWhere(
        (p) => p.id == IPromemoria.idMisure,
      );

      expect(
        misure.quando.day,
        3,
        reason: '🔑 26 settembre + 7 = 3 ottobre, non il lunedi 28.',
      );
      expect(misure.quando.month, 10);
    });
  });

  group('gli identificativi', () {
    /// 🚨 **Non si toccano quelli del cronometro del recupero.**
    ///
    /// ⛔ `RestTimer` usa 8801 e 8802. Un id ripetuto non da' nessun errore:
    /// **sovrascrive** la notifica dell'altro, e il sintomo sarebbe «il
    /// cronometro del recupero a volte non suona» — la cosa piu' difficile da
    /// collegare ai promemoria.
    ///
    /// 🔎 Si leggono dal sorgente di `RestTimer`, non si scrivono qui: ⚠️ scritti
    /// a mano, questo test resterebbe verde il giorno che qualcuno la' cambia
    /// numero.
    test('non si accavallano con quelli del recupero', () {
      final file = File('lib/src/features/training/rest_timer.dart');

      expect(file.existsSync(), isTrue);

      final suoi = RegExp(r'_id\w*\s*=\s*(\d+)')
          .allMatches(file.readAsStringSync())
          .map((m) => int.parse(m.group(1)!))
          .toSet();

      expect(
        suoi,
        isNotEmpty,
        reason: "🚨 Non trovo gli id di RestTimer: il confronto non prova niente.",
      );

      final nostri = <int>{
        for (var g = 0; g < IPromemoria.giorniAvanti; g++)
          IPromemoria.idAllenamento + g,
        for (var g = 0; g < IPromemoria.giorniAvanti; g++)
          IPromemoria.idDiario + g,
        IPromemoria.idMisure,
      };

      expect(
        nostri.intersection(suoi),
        isEmpty,
        reason:
            '🚨 Un id in comune col cronometro del recupero: ⛔ uno sovrascrive '
            "la notifica dell'altro, senza nessun errore.",
      );
    });

    /// ⚠️ E i blocchi dei due giornalieri non si accavallano fra loro.
    test('e i due blocchi giornalieri non si accavallano fra loro', () {
      expect(
        IPromemoria.idDiario - IPromemoria.idAllenamento,
        greaterThanOrEqualTo(IPromemoria.giorniAvanti),
        reason:
            '🚨 Programmando ${IPromemoria.giorniAvanti} giorni avanti, il blocco '
            "dell'allenamento arriverebbe dentro quello del diario.",
      );
    });
  });

  group('le preferenze', () {
    /// 🔑 **Ogni promemoria implementato ha il suo interruttore.**
    ///
    /// ⛔ Senza, l'unico modo di zittirlo e' spegnere le notifiche **dalle
    /// impostazioni di sistema** — dove si spengono tutte, comprese quelle che
    /// servivano, e da dove nessuno torna a riaccenderle.
    test('i promemoria programmati si possono spegnere uno per uno', () {
      const tutti = PreferenzeDeiPromemoria();

      expect(tutti.acceso(Notifica.promemoriaAllenamento), isTrue);
      expect(tutti.acceso(Notifica.promemoriaDiario), isTrue);
      expect(tutti.acceso(Notifica.promemoriaMisure), isTrue);

      const nessuno = PreferenzeDeiPromemoria(
        allenamento: false,
        diario: false,
        misure: false,
      );

      expect(nessuno.acceso(Notifica.promemoriaAllenamento), isFalse);
      expect(nessuno.acceso(Notifica.promemoriaDiario), isFalse);
      expect(nessuno.acceso(Notifica.promemoriaMisure), isFalse);
    });

    /// ⏱️ `fineRecupero` **non** si spegne da qui: ha il suo interruttore dentro
    /// il player, dove il contesto e' chiaro. ⛔ Due interruttori per la stessa
    /// cosa in posti diversi e nessuno capisce quale conta.
    test('il recupero non si spegne dalle preferenze dei promemoria', () {
      const nessuno = PreferenzeDeiPromemoria(
        allenamento: false,
        diario: false,
        misure: false,
      );

      expect(nessuno.acceso(Notifica.fineRecupero), isTrue);
    });
  });
}

/// 📝 Un plugin finto che **scrive quello che gli si chiede**.
///
/// 🔑 Implementa `PluginDelleNotifiche`, che ha **due metodi**: 💡 e' la fessura
/// che `i_promemoria.dart` espone proprio perche' le regole si possano provare
/// senza un sistema operativo che risponda.
///
/// ⚠️ Il canale, l'icona e il colore non compaiono qui, ed e' giusto: stanno in
/// `IlPluginVero`, perche' sono **aspetto** e non c'entrano con «serve un
/// promemoria?».
class _PluginFinto implements PluginDelleNotifiche {
  final List<_Programmato> programmati = [];
  final List<int> cancellati = [];

  @override
  Future<void> cancella(int id) async => cancellati.add(id);

  @override
  Future<void> programma({
    required int id,
    required String titolo,
    required String corpo,
    required tz.TZDateTime quando,
  }) async {
    programmati.add(
      _Programmato(id: id, titolo: titolo, corpo: corpo, quando: quando),
    );
  }
}

/// 📌 Una notifica programmata, come il finto l'ha ricevuta.
class _Programmato {
  const _Programmato({
    required this.id,
    required this.titolo,
    required this.corpo,
    required this.quando,
  });

  final int id;
  final String titolo;
  final String corpo;
  final tz.TZDateTime quando;
}
