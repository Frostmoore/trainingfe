import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// 🖼️ **L'icona nuova** — `plan_interfaccia.md` I10, 19/11/2026.
///
/// 📌 Il committente, 19/11: fondo **nero**, monogramma **rifatto** dalla
/// nuova icona, anche lo store; la favicon del sito dopo (`decisioni.md`).
///
/// 💡 Sono file generati (`flutter_launcher_icons`, `flutter_native_splash`)
/// e immagini preparate da uno script: nessun test di widget li vede. Questo
/// legge i file e tiene ferme le decisioni — e una trappola.
void main() {
  const fondo = '#111011';

  test('icona adattiva e avvio hanno il fondo scuro deciso', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('adaptive_icon_background: "$fondo"'));
    expect(
      // ⚠️ A inizio riga: anche `icon_background_color:` contiene `color:`.
      RegExp(
        '^\\s+color: "$fondo"',
        multiLine: true,
      ).allMatches(pubspec).length,
      2,
      reason: 'avvio e avvio di Android 12',
    );
    expect(pubspec, contains('icon_background_color: "$fondo"'));
    expect(pubspec, isNot(contains('#0F766E')), reason: 'il teal di prima');

    // ⚠️ E i file generati devono averlo davvero: il pubspec da solo non
    // basta, se qualcuno dimentica di rilanciare i generatori.
    expect(
      File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
      contains('<color name="ic_launcher_background">$fondo</color>'),
    );
    expect(
      File('android/app/src/main/res/values-v31/styles.xml').readAsStringSync(),
      contains(
        '<item name="android:windowSplashScreenBackground">$fondo</item>',
      ),
    );
  });

  /// 🚨 **La trappola, ripresentata il 19/11**: `flutter_native_splash:create`
  /// riscrive il manifest e **toglie** `android:screenOrientation="portrait"`.
  /// Era già successo una volta (il manifest lo dice in un commento), ed è
  /// successo di nuovo generando l'avvio nuovo.
  test('il manifest tiene l\'app in verticale', () {
    /*
     * ⚠️ **Nel tag `<activity>`, non ovunque**: la stessa stringa sta anche nel
     * commento che racconta la trappola, e la prima stesura di questo test
     * passava col difetto rimesso (falsificato il 19/11). `[^>]` si ferma alla
     * fine del tag, e attraversa gli a capo fra gli attributi.
     */
    expect(
      RegExp(r'<activity\b[^>]*android:screenOrientation="portrait"').hasMatch(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      ),
      isTrue,
    );
  });

  test('il monogramma è il cerchio dell\'icona nuova, trasparente fuori', () {
    final segno = img.decodePng(
      File('assets/marchio/segno.png').readAsBytesSync(),
    )!;

    expect(segno.width, segno.height);
    expect(segno.numChannels, 4);

    // Fuori dal cerchio (gli angoli): trasparente.
    expect(segno.getPixel(2, 2).a, 0);
    expect(segno.getPixel(segno.width - 3, segno.height - 3).a, 0);

    // ⚠️ Dentro, vicino al bordo: **pieno e scuro** — il fondo dell'emblema.
    // Il segno di prima era bianco su trasparente, e qui sarebbe trasparente.
    final bordo = segno.getPixel(segno.width ~/ 2, 30);
    expect(bordo.a, 255);
    expect(bordo.r + bordo.g + bordo.b, lessThan(200));
  });
}
