import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🔑 **Un permesso solo, e si chiede dove il motivo si vede** — voce 62.3,
/// 27/09/2026.
///
/// ══ 📌 IL FATTO DA CUI PARTE TUTTO ════════════════════════════════════════
///
/// 🚨 **Su Android e su iOS il permesso delle notifiche e' UNO.** Non esiste un
/// «si' alle locali, no alle push»: chi dice no dice no a tutto, compreso il
/// cronometro del recupero.
///
/// ⛔ Quindi la domanda «come separiamo i due permessi?» non ha risposta a livello
/// di sistema operativo. 💡 Quello che si puo' scegliere e' **quando** chiederlo, e
/// quella scelta decide se il si' arrivera' o no.
///
/// ══ ⛔ IL DIFETTO CHE QUESTO TEST CHIUDE ══════════════════════════════════
///
/// 🚨 `NotifichePush._registraIlTokenAttuale()` chiamava
/// `FirebaseMessaging.instance.requestPermission()` **al login**: la prima cosa
/// che una persona nuova vedeva era il dialogo di sistema, senza nessun motivo
/// davanti.
///
/// ⛔ E `notifications.dart` lo scrive a due file di distanza: *«chiederlo
/// all'avvio, prima che l'utente abbia capito a cosa serve, e' il modo piu' rapido
/// per farselo negare per sempre»*. 🚨 Lo scriveva, e intanto la' lo si faceva —
/// che e' la forma peggiore di commento sbagliato: quella che descrive una regola
/// che il codice accanto viola.
///
/// ══ 🔎 PERCHE' UN TEST SUL SORGENTE E NON SUL COMPORTAMENTO ═══════════════
///
/// ⚠️ Non si puo' provare «il dialogo di sistema non compare» in un test: il
/// dialogo lo mostra il sistema operativo, e in un test non c'e'. 💡 Quello che si
/// puo' fare e' tenere ferma la **forma**: nessuna richiesta di permesso dentro il
/// giro delle push.
///
/// ⚖️ E' una guardia debole quanto basta: ⛔ non impedisce tutto, ma impedisce
/// esattamente la riga che era sbagliata — e la impedisce anche a chi non legge
/// questo commento.
void main() {
  test('le push non chiedono il permesso delle notifiche', () {
    final file = File('lib/src/core/notifications/notifiche_push.dart');

    expect(file.existsSync(), isTrue);

    /*
     * 🔎 **Si guardano solo le righe di codice, non i commenti.**
     *
     * ⚠️ Preso al primo giro, il 27/09: il test era rosso per il **commento** che
     * spiega perche' la riga e' stata togliata. ⛔ Vietare anche la spiegazione
     * vorrebbe dire cancellare la cosa che serve di piu' — chi legge quel file
     * deve sapere perche' quella chiamata non c'e'.
     */
    final codice = file
        .readAsStringSync()
        .split('\n')
        .where((r) {
          final pulita = r.trimLeft();

          return !pulita.startsWith('///') &&
              !pulita.startsWith('*') &&
              !pulita.startsWith('/*') &&
              !pulita.startsWith('//');
        })
        .join('\n');

    expect(
      codice.contains('requestPermission('),
      isFalse,
      reason:
          '🚨 Il giro delle push chiede il permesso delle notifiche. ⛔ Gira al '
          'login, quindi lo chiede a freddo: e il permesso e UNO, quindi un no '
          'dato la porta via anche il cronometro del recupero. 💡 Lo chiede '
          'RestTimer, alla prima serie, dove il motivo si vede.',
    );

    /*
     * ✅ E l'altra meta': **il token non si registra senza permesso**. ⛔ Senza
     * questo controllo il test qui sopra passerebbe anche togliendo la richiesta
     * e registrando comunque — e il server crederebbe raggiungibile chi non lo e'.
     */
    expect(
      codice.contains('notificheConsentite()'),
      isTrue,
      reason:
          '🚨 Il token si registra senza guardare il permesso: ⛔ il server '
          'crederebbe raggiungibile una persona che non vedra nessuna notifica.',
    );
  });

  /// 💡 **E qualcuno lo chiede, dove il motivo si vede.**
  ///
  /// 🚨 E' la meta' che rende sicura l'altra: ⛔ togliendo la richiesta dalle push
  /// senza che nessun altro la faccia, il permesso non lo chiederebbe **nessuno** e
  /// le notifiche non arriverebbero mai. 💡 Preso al primo giro il 27/09: cercavo
  /// in `rest_timer.dart`, e chi lo chiede e' `player_screen.dart` — il player, che
  /// e' lo stesso posto e lo stesso momento.
  ///
  /// ⚖️ Non si pretende **quale** file: si pretende che sia chiesto **fuori** dal
  /// giro delle push. ⛔ Fissare il file vorrebbe dire un test rosso il giorno che
  /// il player si sposta, per una cosa che non e' cambiata.
  test('ma qualcuno lo chiede, fuori dal giro delle push', () {
    final chiLoChiede = <String>[];

    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;

      final percorso = f.path.replaceAll(r'\', '/');

      /* ⚠️ Il file che lo **definisce** non conta: conta chi lo chiama. */
      if (percorso.endsWith('core/notifications/notifications.dart')) continue;

      if (f.readAsStringSync().contains('requestNotificationPermission(')) {
        chiLoChiede.add(percorso);
      }
    }

    expect(
      chiLoChiede,
      isNotEmpty,
      reason:
          '🚨 Nessuno chiede il permesso delle notifiche: ⛔ senza, ne le push ne '
          'il cronometro del recupero arriveranno mai a schermo spento.',
    );

    expect(
      chiLoChiede.where((p) => p.contains('notifications/notifiche_push')),
      isEmpty,
      reason:
          '🚨 Lo chiede il giro delle push: ⛔ gira al login, quindi a freddo — ed '
          'e lo stesso difetto di prima con un altro nome.',
    );
  });
}
