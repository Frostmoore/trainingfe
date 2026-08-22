import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// L'app sta in verticale, e i due posti devono restare d'accordo — 22/08/2026.
///
/// ══ 🚨 PERCHÉ UN TEST PER DUE RIGHE ═══════════════════════════════════════
///
/// 📌 Il committente: *«facciamo che l'app deve funzionare solo in portrait
/// mode, mi rompe troppo il cazzo che si gira»*.
///
/// ⚠️ **Il blocco vive in due file, e servono tutti e due**:
///
/// | Dove | Cosa impedisce | Se manca |
/// |---|---|---|
/// | `AndroidManifest.xml` | ad Android di **ruotare la finestra** | l'app gira e si ridisegna prima che Dart possa dire di no |
/// | `main.dart` | a Flutter di accettare le orientazioni | su iOS non c'è nessun blocco, perché il manifest è solo di Android |
///
/// 🚨 **Il difetto che questo test intercetta è la mezza cancellazione**: chi
/// toglie una delle due righe vede l'app ancora bloccata sul proprio telefono
/// Android e conclude che l'altra fosse di troppo. ⛔ Su iOS, o dopo un
/// `flutter create` che riscrive il manifest, salta fuori mesi dopo.
void main() {
  test('il manifest Android blocca la rotazione della finestra', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android:screenOrientation="portrait"'),
      reason:
          'senza questo Android ruota la finestra prima che Dart possa '
          'rifiutare, e si vede il lampo di ridisegno',
    );
  });

  test('main.dart dichiara le sole orientazioni verticali', () {
    final main = File('lib/main.dart').readAsStringSync();

    expect(main, contains('setPreferredOrientations'));
    expect(main, contains('DeviceOrientation.portraitUp'));

    /*
     * ⛔ **E soprattutto: nessuna orizzontale.** La svista vera non è
     * dimenticare la chiamata — è chiamarla con la lista completa copiata da un
     * esempio, che non blocca niente e sembra fatta.
     */
    expect(
      main,
      isNot(contains('DeviceOrientation.landscape')),
      reason: 'una landscape nella lista rende la chiamata una decorazione',
    );
  });
}
