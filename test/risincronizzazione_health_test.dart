import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/ui/aggiornamento.dart';

/// Strisciare in giù risincronizza Health — FASE 1-ter, 20/08/2026.
///
/// ── 🚨 Cosa difende questo file ────────────────────────────────────────────
///
/// La soglia. ⚠️ È una di quelle cose che sembrano un dettaglio e che si
/// rompono in un modo che **non dà errori**: senza, chi striscia cinque volte di
/// fila fa partire cinque letture di Health Connect, e il sintomo è «il telefono
/// scalda e l'app va a scatti» — che non somiglia mai alla sua causa.
///
/// 💡 `RisincronizzazioneHealth` prende l'orologio e l'attesa dal costruttore
/// **apposta**: un test non può aspettare trenta secondi veri, e un
/// `DateTime.now()` chiuso dentro la classe la renderebbe non verificabile.
void main() {
  late int quante;
  late DateTime adesso;

  setUp(() {
    quante = 0;
    adesso = DateTime(2026, 8, 20, 12);
  });

  RisincronizzazioneHealth costruisci({Duration? attesa}) => RisincronizzazioneHealth(
        () async => quante++,
        adesso: () => adesso,
        attesa: attesa,
      );

  test('il primo strisciamento sincronizza', () async {
    final r = costruisci();

    expect(await r.forse(), isTrue);
    expect(quante, 1);
  });

  /// 🚨 Il caso vero: si striscia più volte perché si aspetta che qualcosa
  /// compaia. ⚠️ Cinque letture insieme non fanno arrivare i dati prima, fanno
  /// solo scaldare il telefono.
  test('cinque strisciamenti di fila fanno UNA lettura', () async {
    final r = costruisci();

    for (var i = 0; i < 5; i++) {
      await r.forse();
    }

    expect(quante, 1);
  });

  test('e i quattro rifiutati lo dicono', () async {
    final r = costruisci();

    expect(await r.forse(), isTrue);
    expect(await r.forse(), isFalse);
    expect(await r.forse(), isFalse);
  });

  /// 💡 Trenta secondi: abbastanza da assorbire una raffica, abbastanza poco da
  /// non far sembrare l'app sorda a chi riprova perché *davvero* è cambiato
  /// qualcosa.
  test('dopo l attesa si torna a sincronizzare', () async {
    final r = costruisci();

    await r.forse();
    adesso = adesso.add(RisincronizzazioneHealth.attesaMinima);

    expect(await r.forse(), isTrue);
    expect(quante, 2);
  });

  test('ma un istante prima ancora no', () async {
    final r = costruisci();

    await r.forse();
    adesso = adesso.add(
      RisincronizzazioneHealth.attesaMinima - const Duration(milliseconds: 1),
    );

    expect(await r.forse(), isFalse);
    expect(quante, 1);
  });

  /// ══ 🚨 Il test che difende l'ordine delle righe ══════════════════════════
  ///
  /// Il segnaposto si scrive **prima** della lettura, non dopo. ⚠️ Scrivendolo
  /// alla fine, cinque strisciamenti dentro il secondo che serve a leggere
  /// partirebbero **tutti**: nessuno troverebbe una data recente, perché la
  /// prima non l'ha ancora scritta. La soglia proteggerebbe solo da chi è già
  /// lento — cioè da nessuno.
  test('la soglia vale anche mentre la lettura è ancora in corso', () async {
    // Una lettura lenta, che finisce solo quando glielo diciamo noi.
    final lenta = Completer<void>();
    var partite = 0;

    final r = RisincronizzazioneHealth(
      () {
        partite++;

        return lenta.future;
      },
      adesso: () => adesso,
    );

    // Due strisciamenti nello stesso istante: il secondo arriva mentre il
    // primo sta ancora leggendo.
    final primo = r.forse();
    final secondo = r.forse();

    expect(
      await secondo,
      isFalse,
      reason: 'Il secondo trova il segnaposto già scritto, anche se la lettura non è finita.',
    );

    lenta.complete();
    await primo;

    expect(partite, 1, reason: 'La lettura è partita una volta sola.');
  });

  group('L annuncio — il toast', () {
    /// 📌 Proposto dal committente: *«ci mettiamo un toast che dice
    /// "Aggiornamento dati in corso..."»*. 💡 Chiude un buco che avevo lasciato:
    /// togliendo l'attesa alla rotellina il gesto era diventato **muto**, che è
    /// la stessa forma del difetto del ripristino silenzioso (§2t.8).
    test('si annuncia quando parte', () async {
      final r = costruisci();
      var annunci = 0;

      await r.forse(annuncia: () => annunci++);

      expect(annunci, 1);
    });

    /// ══ 🚨 Il test che conta ═════════════════════════════════════════════
    ///
    /// ⚠️ Se il toast comparisse anche quando la soglia blocca, cinque
    /// strisciate darebbero cinque annunci su un lavoro che **non sta
    /// succedendo**. È una bugia gentile, ed è comunque una bugia: la seconda
    /// volta che uno se ne accorge smette di credere anche ai messaggi veri.
    test('NON si annuncia quando la soglia blocca', () async {
      final r = costruisci();
      var annunci = 0;

      await r.forse(annuncia: () => annunci++);
      await r.forse(annuncia: () => annunci++);
      await r.forse(annuncia: () => annunci++);

      expect(annunci, 1);
    });

    /// ⚠️ **Prima del primo `await`**, quindi il messaggio compare insieme al
    /// gesto e non un fotogramma dopo.
    test('si annuncia PRIMA che la lettura finisca', () async {
      final lenta = Completer<void>();
      var annunciato = false;

      final r = RisincronizzazioneHealth(
        () => lenta.future,
        adesso: () => adesso,
      );

      final futuro = r.forse(annuncia: () => annunciato = true);

      expect(annunciato, isTrue, reason: 'La lettura non è ancora finita.');

      lenta.complete();
      await futuro;
    });

    /// 💡 Il toast è facoltativo: chi chiama `forse()` da un posto senza
    /// schermata — un test, o un domani un lavoro in background — non deve
    /// essere costretto a passarlo.
    test('e senza annuncio funziona lo stesso', () async {
      final r = costruisci();

      expect(await r.forse(), isTrue);
      expect(quante, 1);
    });
  });

  /// ⚠️ Un guasto di Health **non deve rompere lo strisciamento**: la parte
  /// principale dell'aggiornamento è la rete, e Health è un di più.
  test('se la lettura fallisce, non lancia', () async {
    final r = RisincronizzazioneHealth(
      () async => throw StateError('Health Connect non c\'è'),
      adesso: () => adesso,
    );

    await expectLater(r.forse(), completes);
  });

  /// 🚨 E il fallimento **consuma comunque la soglia**: altrimenti un telefono
  /// senza Health Connect — dove ogni lettura fallisce — riproverebbe a ogni
  /// singolo strisciamento, per sempre.
  test('e un fallimento consuma comunque la soglia', () async {
    var tentativi = 0;

    final r = RisincronizzazioneHealth(
      () async {
        tentativi++;

        throw StateError('Health Connect non c\'è');
      },
      adesso: () => adesso,
    );

    await r.forse();
    await r.forse();
    await r.forse();

    expect(tentativi, 1);
  });
}
