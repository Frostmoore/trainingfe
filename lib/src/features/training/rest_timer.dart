import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Il timer di riposo fra una serie e l'altra — C9.3.
///
/// 🚨 **Il conto alla rovescia si calcola da un istante di fine, non
/// decrementando un contatore.**
///
/// Un `Timer.periodic` che fa `secondi--` smette di essere chiamato quando l'app
/// va in background o lo schermo si spegne: al ritorno il numero è fermo dov'era
/// e il riposo risulta più lungo di quanto è stato. Tenendo la **fine** e
/// ricalcolando la differenza, il valore resta giusto anche se nel mezzo non è
/// girato niente.
///
/// 🚨 **L'avviso è una notifica PROGRAMMATA, non un suono allo scadere.**
/// Su iOS il codice Dart in background non gira: aspettare lo scadere per
/// suonare significa non suonare mai, proprio nel caso che conta — telefono in
/// tasca fra una serie e l'altra. La notifica si programma all'avvio del riposo
/// e si **cancella** se lo si salta, si **riprogramma** se lo si allunga.
class RestTimer extends ChangeNotifier {
  RestTimer({FlutterLocalNotificationsPlugin? notifiche})
    : _notifiche = notifiche ?? FlutterLocalNotificationsPlugin();

  /// 🚨 **I canali Android sono IMMUTABILI dopo la prima creazione.**
  ///
  /// Suono, importanza e vibrazione si fissano quando il canale nasce: cambiarli
  /// nel codice **non ha nessun effetto** su un telefono che ha già installato
  /// una versione precedente. È il motivo per cui il recupero finiva in silenzio
  /// pur avendo `playSound: true` scritto nel codice — il canale era nato muto e
  /// nessuna modifica poteva più svegliarlo. Cambiando idea su come deve
  /// avvisare, si cambia **anche l'identificativo**: è l'unico modo.
  static const _canaleFine = 'rest_timer_v2';
  static const _canaleInCorso = 'rest_timer_ongoing_v2';

  /// Un id solo: programmarne una nuova sostituisce la precedente invece di
  /// accumulare una notifica per ogni serie.
  static const _idNotifica = 8801;

  /// L'id della notifica **persistente** con il conto alla rovescia.
  ///
  /// Diverso da `_idNotifica` perché le due convivono: una resta in tendina
  /// mentre il recupero scorre, l'altra suona quando finisce. Con lo stesso id
  /// la seconda sostituirebbe la prima e non ci sarebbe nessun avviso.
  static const _idPersistente = 8802;

  final FlutterLocalNotificationsPlugin _notifiche;

  /// Sostituibile nei test: programmare una notifica vera richiede i canali
  /// della piattaforma, che in un test di unità non esistono.
  @visibleForTesting
  bool notificheAttive = true;

  Timer? _tick;
  DateTime? _fine;
  int _totale = 0;

  bool get attivo => _fine != null;

  int get totale => _totale;

  /// I secondi che mancano, calcolati **adesso**.
  int get rimanenti {
    final fine = _fine;

    if (fine == null) return 0;

    final mancanti = fine.difference(DateTime.now()).inSeconds;

    return mancanti > 0 ? mancanti : 0;
  }

  double get progresso => _totale == 0 ? 0 : (_totale - rimanenti) / _totale;

  String get testo {
    final s = rimanenti;

    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> avvia(int secondi) async {
    if (secondi <= 0) return;

    _totale = secondi;
    _fine = DateTime.now().add(Duration(seconds: secondi));

    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (rimanenti <= 0) {
        _concludi();
      } else {
        notifyListeners();
      }
    });

    notifyListeners();

    await _programmaAvviso(secondi);
    await _mostraPersistente(_fine!);
  }

  /// Allunga o accorcia il riposo.
  ///
  /// ⚠️ Riprogramma la notifica: lasciarla dov'era la farebbe suonare in
  /// anticipo, cioè esattamente ciò che si stava evitando premendo «+15 s».
  ///
  /// 🚨 **Con un valore negativo il recupero non va sotto zero: finisce.**
  /// Senza questo, tre volte «−15 s» su un recupero da 30 secondi lascerebbero
  /// un istante di fine nel passato: `rimanenti` risponderebbe 0, ma `attivo`
  /// resterebbe vero e la barra rimarrebbe piantata su «0:00» finché non la si
  /// salta a mano.
  Future<void> aggiungi(int secondi) async {
    if (!attivo) return;

    if (secondi < 0 && rimanenti + secondi <= 0) {
      _concludi();

      await _annullaAvviso();
      await _togliPersistente();

      return;
    }

    _fine = _fine!.add(Duration(seconds: secondi));

    // Il totale non scende sotto ciò che resta, o la barra di progresso
    // tornerebbe indietro invece di avanzare.
    _totale = (_totale + secondi).clamp(rimanenti, 24 * 3600);

    notifyListeners();

    await _programmaAvviso(rimanenti);
    // Anche la persistente si rifà: mostra un istante di fine, e quello è
    // appena cambiato.
    await _mostraPersistente(_fine!);
  }

  Future<void> salta() async {
    _ferma();

    await _annullaAvviso();
    await _togliPersistente();

    notifyListeners();
  }

  void _ferma() {
    _tick?.cancel();
    _tick = null;
    _fine = null;
    _totale = 0;
  }

  void _concludi() {
    _ferma();

    // 🚨 **Si avvisa in tre modi, e non è ridondanza.**
    //
    // Il caso vero è: telefono appoggiato sulla panca, palestra rumorosa,
    // l'utente sta guardando altrove. Ognuno dei tre copre un buco degli altri:
    //  - la **vibrazione** funziona anche a suoneria spenta;
    //  - il **suono di sistema** arriva anche se le notifiche sono negate;
    //  - la **notifica** è l'unica che arriva a schermo spento.
    //
    // Prima c'era solo `HapticFeedback.heavyImpact()`, che su molti telefoni è
    // un tocco appena percettibile — e su un emulatore non è niente affatto.
    HapticFeedback.vibrate();
    unawaited(SystemSound.play(SystemSoundType.alert));
    unawaited(_suonaAdesso());

    // ⚠️ La persistente va tolta **subito**: con il recupero finito resterebbe
    // in tendina a mostrare «0:00», e una notifica che non corrisponde a niente
    // è peggio di nessuna notifica.
    unawaited(_togliPersistente());

    notifyListeners();
  }

  /// L'avviso **immediato**, per quando il recupero finisce ad app aperta.
  ///
  /// ⚠️ Non basta la notifica programmata: senza il permesso per le sveglie
  /// esatte si ricade su `inexactAllowWhileIdle`, e il sistema può farla
  /// scattare **decine di secondi dopo**. In primo piano lo sappiamo noi che è
  /// finita, e possiamo dirlo subito.
  ///
  /// La programmata resta comunque: è l'unica che arriva a schermo spento.
  /// Si cancella qui per non farne suonare due.
  Future<void> _suonaAdesso() async {
    if (!notificheAttive) return;

    try {
      await _annullaAvviso();

      await _notifiche.show(
        _idNotifica,
        'Riposo finito',
        'Vai con la prossima serie.',
        const NotificationDetails(
          android: _dettagliFine,
          iOS: DarwinNotificationDetails(
            presentSound: true,
            presentAlert: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
      );
    } on Object catch (_) {
      // Senza permesso non si mostra niente: restano vibrazione e suono di
      // sistema, ed è il motivo per cui sono tre e non uno.
    }
  }

  /// Come deve avvisare la notifica di fine — un posto solo.
  ///
  /// Serve sia alla programmata sia a quella immediata: due copie divergono, e
  /// la copia sbagliata è quella che resta muta.
  static const AndroidNotificationDetails _dettagliFine = AndroidNotificationDetails(
    _canaleFine,
    'Fine del recupero',
    channelDescription: 'Suona e vibra quando finisce il recupero fra le serie.',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.alarm,
    playSound: true,
    enableVibration: true,
    // Una pulsazione lunga: fra le serie il telefono è appoggiato, e un
    // singolo colpo breve non si sente.
    vibrationPattern: null,
    fullScreenIntent: false,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );

  Future<void> _programmaAvviso(int fraSecondi) async {
    if (!notificheAttive || fraSecondi <= 0) return;

    try {
      await _annullaAvviso();

      await _notifiche.zonedSchedule(
        _idNotifica,
        'Riposo finito',
        'Vai con la prossima serie.',
        tz.TZDateTime.now(tz.local).add(Duration(seconds: fraSecondi)),
        const NotificationDetails(
          android: _dettagliFine,
          iOS: DarwinNotificationDetails(
            presentSound: true,
            // Su iOS, senza questo, una notifica ad app aperta non suona: e
            // il caso «app aperta sulla panca» è quello che capita di più.
            presentAlert: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        // 🚨 Esatta **solo se il permesso c'è già**, altrimenti inesatta.
        //
        // Chiedere il permesso per le sveglie esatte apre una schermata di
        // sistema che da Android 14 è grigia e non attivabile per un'app come
        // questa: l'utente si ritrova fuori dall'allenamento, in un vicolo
        // cieco, nel mezzo di una serie. Una notifica inesatta arriva con
        // qualche secondo di ritardo — incomparabilmente meglio.
        androidScheduleMode: await _puoProgrammareEsatte()
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        // L'istante è **assoluto**: se il telefono cambia fuso mentre si
        // riposa (succede in aereo, non in palestra) il recupero non deve
        // allungarsi o accorciarsi di un'ora.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on Object catch (_) {
      /*
       * ⚠️ Silenzio voluto, e con un motivo preciso.
       *
       * Senza il permesso di notifica — o senza quello per le sveglie esatte su
       * Android 13+ — programmare fallisce. Il riposo deve funzionare lo stesso,
       * solo senza avviso a schermo spento: far fallire una serie perché manca
       * un permesso sarebbe sproporzionato rispetto al danno.
       */
    }
  }

  /// La notifica che resta in tendina e **conta alla rovescia da sola**.
  ///
  /// 🚨 **Il conto alla rovescia lo disegna Android, non noi.**
  /// `usesChronometer` + `chronometerCountDown` + `when` all'istante di fine:
  /// il sistema aggiorna i secondi anche con l'app chiusa e senza che giri una
  /// riga di Dart. È l'unico modo onesto di avere un timer vivo in background:
  /// l'alternativa — tenere vivo un isolate o un foreground service — vuol dire
  /// batteria consumata, un permesso in più da giustificare sugli store, e un
  /// processo che il sistema può comunque uccidere.
  ///
  /// ⚠️ `importance: low` e `silent`: questa non deve suonare né vibrare. Il
  /// suono è dell'**altra** notifica, quella di fine. Se suonassero entrambe,
  /// il telefono squillerebbe all'**inizio** del recupero — cioè nel momento
  /// esatto in cui non serve.
  ///
  /// `timeoutAfter` la fa sparire da sola qualche secondo dopo la fine: se
  /// l'app resta chiusa, `_concludi()` non gira e senza questo la notifica
  /// resterebbe in tendina a mostrare «0:00» per sempre.
  Future<void> _mostraPersistente(DateTime fine) async {
    if (!notificheAttive) return;

    final mancano = fine.difference(DateTime.now()).inMilliseconds;

    if (mancano <= 0) return;

    try {
      await _notifiche.show(
        _idPersistente,
        'Recupero in corso',
        'Tocca per tornare all\'allenamento.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _canaleInCorso,
            'Recupero in corso',
            channelDescription:
                'Mostra quanto manca alla fine del recupero mentre l\'app è chiusa.',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            silent: true,
            showWhen: true,
            when: fine.millisecondsSinceEpoch,
            usesChronometer: true,
            chronometerCountDown: true,
            timeoutAfter: mancano + 5000,
          ),
          // ⚠️ Su iOS non esiste niente di equivalente: una notifica non si
          // aggiorna da sola. Meglio non mostrarne una ferma su un numero
          // sbagliato — lì resta solo l'avviso di fine.
          iOS: null,
        ),
      );
    } on Object catch (_) {
      // Senza permesso di notifica non si mostra niente, e il recupero
      // funziona lo stesso in primo piano. Vedi la nota in `_programmaAvviso`.
    }
  }

  Future<void> _togliPersistente() async {
    if (!notificheAttive) return;

    try {
      await _notifiche.cancel(_idPersistente);
    } on Object catch (_) {
      // Vedi sopra.
    }
  }

  /// Se il sistema ci lascia programmare sveglie esatte.
  ///
  /// ⚠️ Su iOS e sui vecchi Android la domanda non ha senso e la risposta è
  /// sì. Se il plugin non risponde si assume **no**: programmare una esatta
  /// senza permesso lancia, e a quel punto non arriverebbe nessuna notifica —
  /// mentre una inesatta arriva comunque.
  Future<bool> _puoProgrammareEsatte() async {
    try {
      final android = _notifiche
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (android == null) return true;

      return await android.canScheduleExactNotifications() ?? false;
    } on Object {
      return false;
    }
  }

  Future<void> _annullaAvviso() async {
    if (!notificheAttive) return;

    try {
      await _notifiche.cancel(_idNotifica);
    } on Object catch (_) {
      // Vedi sopra.
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}
