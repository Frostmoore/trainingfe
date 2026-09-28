import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'preferenze_dei_promemoria.dart';

/// 📱 **I quattro promemoria locali** — voce 62, 27/09/2026.
///
/// ══ 📌 PERCHE' SONO LOCALI E NON PUSH ═════════════════════════════════════
///
/// 🚨 **Il server non sa quando ti alleni, cosa mangi e quanto pesi**: la scheda,
/// il diario e le misure stanno sul telefono (A1, 22/09/2026). ⛔ Mandare questi
/// promemoria in push vorrebbe dire dirglielo — e dirlo anche a Google, che è il
/// sub-responsabile che le push si portano dietro.
///
/// 💡 `App\Enums\CanaleDellaNotifica` nel backend scrive la regola in una riga:
/// *«è push solo se l'evento che la genera è già sul server»*. ⚖️ Qui l'evento
/// **non** c'è: è «non hai fatto una cosa», e quel non-fatto lo sa solo il
/// telefono.
///
/// ══ 🔑 UN SOLO POSTO CHE PROGRAMMA ════════════════════════════════════════
///
/// 📌 Il committente: *«Voglio un solo punto dove posso aggiungere notifiche»*.
/// 💡 Di là è l'enum `Notifica`; di qua è questa classe: ⛔ nessun'altra parte
/// dell'app chiama `zonedSchedule` per un promemoria, e
/// `test/i_promemoria_test.dart` lo verifica.
///
/// ⚠️ L'unica locale che sta **fuori** da qui è `fineRecupero`, e per una ragione:
/// vive dentro il player (`RestTimer`), si programma all'inizio del riposo e si
/// cancella se lo salti. 🚨 Portarla qui vorrebbe dire far dipendere il
/// cronometro da un programmatore che gira all'apertura dell'app.
///
/// ══ 🚨 PERCHE' SI RIPROGRAMMA TUTTO OGNI VOLTA ════════════════════════════
///
/// ⛔ Una notifica programmata **non è condizionale**: `zonedSchedule` suona a
/// quell'ora e basta, non può chiedersi «si è allenato?» quando arriva il
/// momento.
///
/// 💡 Quindi si fa il contrario: si guarda lo stato **adesso** e si programma di
/// conseguenza, cancellando tutto prima. ⚠️ E si programmano **più giorni
/// avanti**, non solo il prossimo: 🔑 è la parte che fa funzionare «sono tre
/// giorni che non ti alleni» — se una persona non apre l'app, i promemoria messi
/// l'ultima volta continuano ad arrivare, che è esattamente quello che serve.
///
/// 🚨 Il rovescio, ed è scritto perché non sorprenda: chi **non apre l'app per
/// più di [giorniAvanti] giorni** smette di ricevere promemoria finché non la
/// riapre. ⚖️ È il limite delle notifiche locali senza lavoro in background, e
/// l'alternativa — un risveglio periodico in background — costa batteria e su
/// iOS non è garantito.
class IPromemoria {
  const IPromemoria(this._notifiche);

  final PluginDelleNotifiche _notifiche;

  /// 📆 Quanti giorni avanti si programma.
  ///
  /// ⚖️ Sette perché è il ciclo su cui è fatto tutto il resto (la settimana
  /// programmata, le misure settimanali): ⛔ meno vorrebbe dire che una vacanza
  /// di cinque giorni spegne i promemoria, e molti di più vorrebbe dire
  /// programmare decine di notifiche che verranno cancellate alla prossima
  /// apertura.
  static const giorniAvanti = 7;

  /*
   * 🔢 **Gli identificativi, a blocchi di dieci.**
   *
   * 🚨 `RestTimer` usa **8801** e **8802**: un numero ripetuto non dà nessun
   * errore, sovrascrive la notifica dell'altro — e il sintomo sarebbe «il
   * cronometro del recupero a volte non suona», cioè la cosa più difficile da
   * collegare a questo file.
   *
   * 💡 A blocchi di dieci perché i due promemoria giornalieri ne usano uno per
   * giorno: `8810 + 0..6`, `8820 + 0..6`.
   */
  static const idAllenamento = 8810;
  static const idDiario = 8820;
  static const idMisure = 8830;

  /*
   * ⛔ **8840 era «scheda finita», e il caso non esiste piu'** — 27/09, chiuso
   * il 28/09.
   *
   * 🚨 Il 27/09 avevo scritto il meccanismo e l'avevo toltato subito, perche'
   * **non c'era niente su cui farlo scattare**: `SchedaAllenamento` ha id,
   * origineId e giorni, e nessuna durata o conteggio di cicli;
   * `SettimanaProgrammata` mappa giorno -> scheda ed e' **ricorrente**. ⛔ Senza
   * chi lo chiama era lo stesso residuo di `PlanImportResource::iscritti()`:
   * codice che fa **credere** implementata una cosa che non parte mai.
   *
   * 💡 Il 28/09 il committente ha sciolto il dubbio: *«Che cazzo significa
   * scheda finita?? Le schede non finiscono. Al massimo finisce
   * l'allenamento»*. 🔑 Quindi il caso e' stato **togliato anche dal catalogo**,
   * di qua e dal backend: non era «da fare», era una cosa che il prodotto non
   * ha.
   *
   * ⚠️ **«Allenamento finito» non e' il sostituto**: chiudendo una seduta hai il
   * telefono in mano e la schermata davanti, e una notifica li' e' rumore.
   *
   * 💡 Il numero 8840 resta libero, se un giorno una scheda dovesse avere una
   * fine.
   */

  /// 🔄 **Cancella e riprogramma tutto**, secondo lo stato e le preferenze.
  ///
  /// ══ ⚠️ PERCHE' CANCELLA PRIMA ═════════════════════════════════════════
  ///
  /// 🚨 Senza, un promemoria spostato dalle 18 alle 20 suonerebbe **due volte**:
  /// `zonedSchedule` con un id già usato lo sostituisce, ma i giorni che non si
  /// riprogrammano — perché ora si è allenato, o perché ha spento
  /// l'interruttore — resterebbero in piedi.
  ///
  /// 💡 Da chiamare all'apertura dell'app e dopo ogni fatto che cambia la
  /// risposta: una seduta finita, una voce di diario, una pesata, un
  /// interruttore toccato.
  Future<void> riprogramma({
    required StatoDeiPromemoria stato,
    required PreferenzeDeiPromemoria preferenze,
    DateTime? adesso,
  }) async {
    final ora = adesso ?? DateTime.now();

    /*
     * 🕐 **Un solo orologio, e sta qui** — corretto il 27/09/2026.
     *
     * ⛔ Prima i metodi qui sotto confrontavano gli istanti calcolati da `ora`
     * con `tz.TZDateTime.now(tz.local)`, cioe' con l'orologio **di sistema**.
     * 🚨 Due orologi vogliono dire che il comportamento dipende da quale dei due
     * e' avanti: in produzione coincidono quasi sempre, ed e' esattamente per
     * questo che un difetto del genere sopravvive — si vede solo quando non
     * coincidono.
     *
     * 💡 Da qui in giu' l'unico «adesso» e' questo.
     */
    final adessoTz = tz.TZDateTime.from(ora, tz.local);

    try {
      await _cancellaTutti();

      if (preferenze.allenamento) {
        await _giornalieri(
          primoId: idAllenamento,
          ora: preferenze.oraAllenamento,
          adesso: ora,
          ultimaVolta: stato.ultimoAllenamento,
          adessoTz: adessoTz,
          titolo: 'Ci alleniamo?',
          corpo: _corpoAllenamento,
        );
      }

      if (preferenze.diario) {
        await _giornalieri(
          primoId: idDiario,
          ora: preferenze.oraDiario,
          adesso: ora,
          ultimaVolta: stato.ultimaVoceDiario,
          adessoTz: adessoTz,
          titolo: 'Hai segnato quello che hai mangiato?',
          corpo: (_) => 'Segnare i pasti la sera costa un minuto e serve tutto il mese.',
        );
      }

      if (preferenze.misure) {
        await _settimanale(
          preferenze: preferenze,
          adesso: ora,
          adessoTz: adessoTz,
          ultimaMisura: stato.ultimaMisura,
        );
      }
    } on Object catch (errore) {
      /*
       * ⚠️ Silenzio in produzione: ⛔ un'app che non parte perché non riesce a
       * programmare un promemoria sarebbe sproporzionata. 💡 Il caso normale è
       * il permesso negato, che non è un guasto.
       */
      if (kDebugMode) debugPrint('Promemoria non programmati: $errore');
    }
  }

  /// 🧹 Toglie tutti i promemoria di questa classe, e **solo** quelli.
  ///
  /// 🚨 **Non `cancelAll()`**: ⛔ quello porterebbe via anche la notifica del
  /// recupero in corso (`RestTimer`, id 8801/8802) — e il sintomo sarebbe un
  /// cronometro che smette di suonare quando si apre un'altra schermata.
  Future<void> _cancellaTutti() async {
    for (var g = 0; g < giorniAvanti; g++) {
      await _notifiche.cancella(idAllenamento + g);
      await _notifiche.cancella(idDiario + g);
    }

    await _notifiche.cancella(idMisure);
  }

  /// ✍️ Il testo dell'allenamento cambia con i giorni passati.
  ///
  /// ⚖️ **Non è un vezzo**: «sono cinque giorni che non ti alleni» a chi si è
  /// allenato ieri è falso, e una notifica che dice il falso la si spegne. 💡 Il
  /// numero viene calcolato per il giorno in cui la notifica **suonerà**, non per
  /// oggi.
  static String _corpoAllenamento(int giorniSenza) => switch (giorniSenza) {
    <= 1 => 'Se oggi tocca a te, il telefono è già pronto.',
    2 => 'Due giorni di pausa: oggi è un buon giorno per rientrare.',
    3 || 4 => 'Sono $giorniSenza giorni che non ti alleni.',
    _ => 'Sono $giorniSenza giorni. Anche mezz\'ora conta più di zero.',
  };

  /// 📅 I promemoria giornalieri, da domani in poi (o da oggi se l'ora non è
  /// ancora passata) **e solo per i giorni in cui servono**.
  ///
  /// ══ 🔑 LA REGOLA CHE EVITA IL PROMEMORIA INUTILE ══════════════════════
  ///
  /// ⚠️ Il **primo** giorno si salta se la cosa è già stata fatta oggi: 💡 chi si
  /// è allenato stamattina non deve sentirsi chiedere alle 18 se si allena.
  ///
  /// 🚨 I giorni successivi si programmano **tutti**: da qui non si può sapere se
  /// domani si allenerà. ⛔ E va bene così: se domani lo fa, l'app si apre, e
  /// aprendosi riprogramma — cancellando quello di domani prima che suoni.
  Future<void> _giornalieri({
    required int primoId,
    required TimeOfDay ora,
    required DateTime adesso,
    required DateTime? ultimaVolta,
    required tz.TZDateTime adessoTz,
    required String titolo,
    required String Function(int giorniSenza) corpo,
  }) async {
    final fattoOggi = ultimaVolta != null && _stessoGiorno(ultimaVolta, adesso);

    for (var g = 0; g < giorniAvanti; g++) {
      if (g == 0 && fattoOggi) continue;

      final quando = _alle(adesso, ora, fraGiorni: g);

      /* ⏭️ L'ora di oggi è già passata: il primo utile è domani. */
      if (!quando.isAfter(adessoTz)) continue;

      final giorniSenza = ultimaVolta == null
          ? g + 1
          : _giorniFra(ultimaVolta, adesso.add(Duration(days: g)));

      await _programma(primoId + g, titolo, corpo(giorniSenza), quando);
    }
  }

  /// ⚖️ Il promemoria delle misure: una volta a settimana, nel suo giorno.
  ///
  /// ⚠️ Si salta se una misura c'è **già in questa settimana**: 💡 chi si è pesato
  /// martedì non va richiamato il lunedì dopo per sei giorni.
  Future<void> _settimanale({
    required PreferenzeDeiPromemoria preferenze,
    required DateTime adesso,
    required tz.TZDateTime adessoTz,
    required DateTime? ultimaMisura,
  }) async {
    if (ultimaMisura != null && _giorniFra(ultimaMisura, adesso) < 7) {
      /*
       * 💡 Si è pesato di recente: il prossimo richiamo è **dopo** sette giorni
       * da quella pesata, non al prossimo lunedì.
       */
      final prossimo = _alle(
        ultimaMisura.add(const Duration(days: 7)),
        preferenze.oraMisure,
      );

      if (prossimo.isAfter(adessoTz)) {
        await _programma(
          idMisure,
          'Peso e misure',
          'È passata una settimana: due numeri adesso valgono un grafico fra un mese.',
          prossimo,
        );
      }

      return;
    }

    /* 📆 Nessuna misura recente: il prossimo giorno scelto. */
    final giorni = (preferenze.giornoMisure - adesso.weekday) % 7;

    var quando = _alle(adesso, preferenze.oraMisure, fraGiorni: giorni);

    if (!quando.isAfter(adessoTz)) {
      quando = _alle(adesso, preferenze.oraMisure, fraGiorni: giorni + 7);
    }

    await _programma(
      idMisure,
      'Peso e misure',
      'Un peso a digiuno, adesso, e i progressi si vedranno davvero.',
      quando,
    );
  }

  Future<void> _programma(
    int id,
    String titolo,
    String corpo,
    tz.TZDateTime quando,
  ) async {
    await _notifiche.programma(
      id: id,
      titolo: titolo,
      corpo: corpo,
      quando: quando,
    );
  }

  /// 🕐 L'istante di `ora` nel giorno `fraGiorni` a partire da `da`.
  static tz.TZDateTime _alle(
    DateTime da,
    TimeOfDay ora, {
    int fraGiorni = 0,
  }) {
    final giorno = DateTime(da.year, da.month, da.day).add(
      Duration(days: fraGiorni),
    );

    return tz.TZDateTime(
      tz.local,
      giorno.year,
      giorno.month,
      giorno.day,
      ora.hour,
      ora.minute,
    );
  }

  static bool _stessoGiorno(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 📏 Quanti giorni **di calendario** fra due istanti.
  ///
  /// ⚠️ Si azzerano le ore: ⛔ `difference().inDays` fra ieri sera e stamattina
  /// dà **zero**, e «sono zero giorni che non ti alleni» dopo una notte è falso.
  static int _giorniFra(DateTime prima, DateTime dopo) {
    final a = DateTime(prima.year, prima.month, prima.day);
    final b = DateTime(dopo.year, dopo.month, dopo.day);

    return b.difference(a).inDays;
  }
}

/// 🔌 **La fessura fra i promemoria e il telefono** — voce 62, 27/09/2026.
///
/// ══ 📌 PERCHE' ESISTE UN'INTERFACCIA DA DUE METODI ════════════════════════
///
/// 🚨 `IPromemoria` contiene **le regole**: chi riceve, quando, con che testo. ⛔ E
/// le regole scritte contro `FlutterLocalNotificationsPlugin` non si possono
/// provare: quel plugin parla col sistema operativo, e in un test non c'è un
/// sistema operativo che risponda.
///
/// 💡 Due metodi bastano, e sono **i due che le regole usano**: cancellare e
/// programmare. ⚖️ Un finto che ne implementa due si legge in dieci righe; uno
/// che eredita da una classe con trenta metodi nasconde quali contano.
///
/// ══ ⚠️ E IL «COM'E' FATTA» STA NELL'ADATTATORE, NON QUI ═══════════════════
///
/// 🔑 Canale, icona, colore e importanza stanno in [IlPluginVero]: ⚖️ sono
/// **aspetto**, e non c'entrano con la domanda «serve un promemoria?». 💡 Così le
/// regole si provano senza dover costruire un `NotificationDetails`.
abstract interface class PluginDelleNotifiche {
  /// 🧹 Toglie la notifica con questo identificativo, se c'è.
  Future<void> cancella(int id);

  /// ⏰ Programma una notifica per quell'istante.
  Future<void> programma({
    required int id,
    required String titolo,
    required String corpo,
    required tz.TZDateTime quando,
  });
}

/// 📱 L'adattatore vero: parla con `flutter_local_notifications`.
class IlPluginVero implements PluginDelleNotifiche {
  IlPluginVero([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _canale = AndroidNotificationDetails(
    'promemoria',
    'Promemoria',
    channelDescription: 'Allenamento, diario, peso e misure',

    /*
     * ⚠️ `defaultImportance` e non `high`, al contrario del canale «avvisi».
     *
     * ⛔ `high` su Android vuol dire **banner a schermo** con suono: giusto per
     * un messaggio che qualcuno ti ha mandato adesso, sbagliato per «non hai
     * segnato la cena». 💡 Un promemoria che interrompe quello che stai facendo
     * viene spento, e con lui tutti gli altri.
     */
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,

    /*
     * 🔔 **La stessa icona monocromatica delle altre** (`ic_notifica`), e la
     * stessa ragione: ⛔ senza, Android riduce l'icona dell'app a sagoma piena e
     * si vede un cerchio bianco.
     */
    icon: 'ic_notifica',
    color: Color(0xFF0F766E),
  );

  static const _dettagli = NotificationDetails(
    android: _canale,
    iOS: DarwinNotificationDetails(
      /*
       * 💡 Su iOS un promemoria non deve suonare: arriva in centro notifiche e
       * lo si legge quando si guarda il telefono. ⚠️ `presentAlert` sì, perché
       * senza non comparirebbe affatto ad app aperta.
       */
      presentSound: false,
      presentAlert: true,
    ),
  );

  @override
  Future<void> cancella(int id) => _plugin.cancel(id);

  @override
  Future<void> programma({
    required int id,
    required String titolo,
    required String corpo,
    required tz.TZDateTime quando,
  }) => _plugin.zonedSchedule(
    id,
    titolo,
    corpo,
    quando,
    _dettagli,

    /*
     * 🚨 **Sempre inesatta, e di proposito.**
     *
     * ⛔ `exactAllowWhileIdle` vuole il permesso delle sveglie esatte, che da
     * Android 14 è **grigio e non attivabile** per un'app come questa: chiederlo
     * butta la persona su una schermata di sistema dove non può fare niente.
     *
     * 💡 E qui non serve proprio: un promemoria del diario che arriva alle 21:07
     * invece delle 21:00 fa lo stesso lavoro. ⚖️ È la differenza con `RestTimer`,
     * dove i secondi contano e quindi si prova l'esatta **solo se il permesso
     * c'è già**.
     */
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,

    /*
     * ⚠️ `absoluteTime`: l'istante è quello, anche se il telefono cambia fuso.
     * 💡 Al contrario del recupero, qui un'ora di differenza si noterebbe — un
     * promemoria serale che arriva nel pomeriggio.
     */
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

/// 📊 **I fatti che decidono se un promemoria serve.**
///
/// ══ 📌 PERCHE' UNA CLASSE DI DATI E NON LE QUERY QUI DENTRO ═══════════════
///
/// 💡 `IPromemoria` non sa niente di drift, e non deve: ⚖️ così si prova con
/// tre date scritte a mano invece che con un database — e le regole che decidono
/// «serve o non serve» sono **esattamente** la parte che va provata caso per
/// caso.
///
/// ⚠️ Le date sono **locali**, non UTC: la domanda è «si è allenato oggi?», e
/// «oggi» è il giorno di chi guarda il telefono.
@immutable
class StatoDeiPromemoria {
  const StatoDeiPromemoria({
    this.ultimoAllenamento,
    this.ultimaVoceDiario,
    this.ultimaMisura,
  });

  /// L'ultima seduta **finita**, non iniziata: 💡 una aperta e abbandonata non
  /// è un allenamento fatto.
  final DateTime? ultimoAllenamento;

  final DateTime? ultimaVoceDiario;
  final DateTime? ultimaMisura;
}
