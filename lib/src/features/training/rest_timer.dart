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

  /// Un id solo: programmarne una nuova sostituisce la precedente invece di
  /// accumulare una notifica per ogni serie.
  static const _idNotifica = 8801;

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
  }

  /// Allunga il riposo.
  ///
  /// ⚠️ Riprogramma la notifica: lasciarla dov'era la farebbe suonare in
  /// anticipo, cioè esattamente ciò che si stava evitando premendo «+30s».
  Future<void> aggiungi(int secondi) async {
    if (!attivo) return;

    _fine = _fine!.add(Duration(seconds: secondi));
    _totale += secondi;

    notifyListeners();

    await _programmaAvviso(rimanenti);
  }

  Future<void> salta() async {
    _ferma();

    await _annullaAvviso();

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

    // In primo piano la vibrazione arriva subito; per lo schermo spento c'è la
    // notifica, già in coda da quando il riposo è cominciato.
    HapticFeedback.heavyImpact();

    notifyListeners();
  }

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
          android: AndroidNotificationDetails(
            'rest_timer',
            'Timer di riposo',
            channelDescription: 'Avvisa quando finisce il recupero fra le serie.',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
          ),
          iOS: DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
