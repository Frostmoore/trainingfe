import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// La release deve poter aprire una connessione — 14/08/2026.
///
/// ── 🚨 Il difetto ────────────────────────────────────────────────────────
///
/// Riferito come *«non funziona la registrazione, dice impossibile connettersi
/// al server»*. Il server rispondeva `201` a una registrazione vera fatta da
/// riga di comando: non era il server.
///
/// ⚠️ **Il template di Flutter dichiara `android.permission.INTERNET` solo in
/// `android/app/src/debug/` e `android/app/src/profile/`**, non nel manifest
/// principale. In sviluppo si gira sempre in debug — dove il permesso c'è — e la
/// **release** non era mai stata installata su niente: il difetto è rimasto
/// invisibile fino al primo APK vero.
///
/// ── 🚨 Perché un test su un file XML, che è una cosa insolita ─────────────
///
/// Perché **non c'è nessun altro posto** in cui questo si rompe rumorosamente.
/// Non è codice Dart: non lo prende `flutter analyze`, non lo prende nessun test
/// di widget, e la build **riesce** — l'APK si costruisce, si installa e si apre.
/// L'unico sintomo è a runtime, su un dispositivo vero, e assomiglia a un guasto
/// di rete.
///
/// 💡 E il sintomo **accusa il posto sbagliato**: «controlla la tua connessione»
/// manda a guardare il wi-fi e poi il server. Ci si arriva solo leggendo l'elenco
/// dei permessi in `logcat` e notando cosa **non** c'è — che non è il primo posto
/// dove chiunque guarderebbe.
void main() {
  test('la release Android dichiara il permesso di rete', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');

    expect(
      manifest.existsSync(),
      isTrue,
      reason: 'il manifest principale non è dove dovrebbe: il test non prova più niente',
    );

    /*
     * 🚨 Si guarda **il manifest principale**, non quello di `debug`: è l'unico
     * che finisce nella release. Cercarlo «da qualche parte in android/»
     * troverebbe quello di sviluppo e direbbe che va tutto bene — che è
     * esattamente l'errore che ha lasciato passare il difetto.
     */
    expect(
      manifest.readAsStringSync(),
      contains('android.permission.INTERNET'),
      reason: 'senza questo, ogni chiamata della release fallisce e l\'app accusa la rete del telefono',
    );
  });
}
