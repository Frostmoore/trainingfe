import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// 🔔 **L'icona delle notifiche** — 26/09/2026.
///
/// ══ ⛔ IL DIFETTO CHE QUESTI TEST CHIUDONO ══════════════════════════════════
///
/// 📌 Il committente, il 26/09, alla prima notifica arrivata davvero:
/// *«l'icona dell'app nella notifica appare come un cerchio bianco, dovrebbe
/// avere il logo dell'app»*.
///
/// 🚨 Da Android 5 l'icona di una notifica si disegna **col solo canale alpha**:
/// i colori si buttano via e resta la sagoma, riempita di bianco. ⛔ L'icona
/// dell'app ha lo sfondo pieno, quindi la sagoma è **tutto il quadrato** — il
/// cerchio bianco.
///
/// ⚠️ **Non si vede da nessun test di widget e da nessuna analisi**: si vede
/// solo guardando un telefono vero, e solo dopo che le push funzionano. 💡 Per
/// questo qui si guardano i **file**: sono l'unica cosa che una macchina può
/// controllare da sola.
void main() {
  const densita = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
  const misure = {'mdpi': 24, 'hdpi': 36, 'xhdpi': 48, 'xxhdpi': 72, 'xxxhdpi': 96};

  test('c\'è un\'icona per ogni densità, della misura giusta', () {
    for (final d in densita) {
      final file = File('android/app/src/main/res/drawable-$d/ic_notifica.png');

      expect(file.existsSync(), isTrue, reason: 'manca ic_notifica in $d');

      final png = img.decodePng(file.readAsBytesSync())!;

      expect(png.width, misure[d], reason: 'misura sbagliata in $d');
      expect(png.height, misure[d], reason: 'misura sbagliata in $d');
    }
  });

  /// 🚨 **La prova che conta**: ogni pixel visibile dev'essere **bianco**.
  ///
  /// ⛔ Un'icona coi colori dentro sembra giusta guardando il file e diventa una
  /// macchia bianca sul telefono — che è esattamente com'è cominciata questa
  /// storia.
  test('è bianca su trasparente, e non un quadrato pieno', () {
    final png = img.decodePng(
      File('android/app/src/main/res/drawable-xxxhdpi/ic_notifica.png')
          .readAsBytesSync(),
    )!;

    var visibili = 0;
    var colorati = 0;
    var sinistra = png.width;
    var destra = -1;
    var sopra = png.height;
    var sotto = -1;

    for (var y = 0; y < png.height; y++) {
      for (var x = 0; x < png.width; x++) {
        final p = png.getPixel(x, y);

        if (p.a == 0) continue;

        visibili++;

        if (p.r != 255 || p.g != 255 || p.b != 255) colorati++;

        if (x < sinistra) sinistra = x;
        if (x > destra) destra = x;
        if (y < sopra) sopra = y;
        if (y > sotto) sotto = y;
      }
    }

    expect(colorati, 0, reason: 'ci sono pixel non bianchi: Android li butterà via');

    /*
     * 🆕 🚨 **E dev'essere grande quanto la tela.** — 26/09/2026.
     *
     * 📌 Il committente, alla seconda prova: *«il monogramma risulta troppo
     * piccolo non si capisce»*.
     *
     * ⛔ La prima versione partiva da `segno.png`, che ha un 26-30% di vuoto
     * per lato, e lo rimpiccioliva **ancora** al 76%: il monogramma copriva il
     * 36% della tela, e sul telefono era un puntino dentro il tondo.
     *
     * 💡 Si misura **l'ingombro del disegno**, non quanti pixel sono accesi:
     * un segno sottile ma grande è giusto, un segno fitto ma piccolo no. 22dp
     * su 24 è la misura che Android si aspetta.
     */
    final ingombro = (destra - sinistra + 1) / png.width;

    expect(
      ingombro,
      greaterThan(0.85),
      reason:
          'il monogramma occupa il ${(ingombro * 100).round()}% della tela: '
          'sul telefono si vedrà un puntino dentro il tondo di Android',
    );

    /*
     * ⚠️ **E non dev'essere piena.** Una silhouette che copre tutto è
     * indistinguibile dal difetto di partenza: il segno del marchio ne occupa
     * meno di un quinto.
     */
    final quota = visibili / (png.width * png.height);

    expect(
      quota,
      lessThan(0.5),
      reason: 'l\'icona copre il ${(quota * 100).round()}% della superficie: '
          'è un quadrato pieno, non una silhouette',
    );
    expect(quota, greaterThan(0.01), reason: 'l\'icona è praticamente vuota');
  });

  /// ⚠️ **I file da soli non bastano**: Android li usa solo se il manifest li
  /// dichiara. ⛔ Generare le icone e dimenticare la riga è il modo di avere
  /// tutto a posto sul disco e il cerchio bianco sul telefono.
  test('il manifest le dichiara, con anche il colore', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(
      manifest.contains('com.google.firebase.messaging.default_notification_icon'),
      isTrue,
      reason: 'il manifest non dichiara l\'icona delle notifiche',
    );
    expect(manifest.contains('@drawable/ic_notifica'), isTrue);
    expect(
      manifest.contains('com.google.firebase.messaging.default_notification_color'),
      isTrue,
    );

    final colori =
        File('android/app/src/main/res/values/colors.xml').readAsStringSync();

    expect(colori.contains('colore_notifica'), isTrue);
  });

  /// 🚨 **E la notifica che mostriamo noi**, con l'app aperta, deve usare la
  /// stessa icona. ⛔ Usava `@mipmap/ic_launcher`: sarebbe restata bianca
  /// proprio nel caso che si prova per ultimo.
  test('anche la notifica in primo piano usa ic_notifica', () {
    final codice =
        File('lib/src/core/notifications/notifiche_push.dart').readAsStringSync();

    expect(
      codice.contains("icon: 'ic_notifica'"),
      isTrue,
      reason: 'la notifica mostrata dall\'app userebbe l\'icona sbagliata',
    );
  });

  /// 🆕 🎨 **E il colore dev'essere lo stesso nei due posti** — 26/09/2026.
  ///
  /// ⚠️ Il colore di una notifica è scritto **due volte**, e deve restare
  /// uguale:
  ///
  /// | Dove | Quando vale |
  /// |---|---|
  /// | `res/values/colors.xml` | l'app è chiusa: la notifica la disegna Android |
  /// | `notifiche_push.dart` | l'app è aperta: la disegna l'app |
  ///
  /// ⛔ Se divergono, la **stessa** notifica cambia colore a seconda di dove ti
  /// trova. 🚨 È una cosa che nessuno va a guardare: la si vede per caso, mesi
  /// dopo, e sembra un difetto a caso. 💡 Perciò la guarda una macchina.
  test('il colore è lo stesso in colors.xml e nel codice', () {
    final colori =
        File('android/app/src/main/res/values/colors.xml').readAsStringSync();
    final codice =
        File('lib/src/core/notifications/notifiche_push.dart').readAsStringSync();

    final daXml = RegExp(
      r'<color name="colore_notifica">#([0-9A-Fa-f]{6})</color>',
    ).firstMatch(colori)?.group(1)?.toUpperCase();

    final daDart = RegExp(
      r'color: Color\(0xFF([0-9A-Fa-f]{6})\)',
    ).firstMatch(codice)?.group(1)?.toUpperCase();

    expect(daXml, isNotNull, reason: 'colore_notifica non si legge da colors.xml');
    expect(daDart, isNotNull, reason: 'il colore del canale non si legge dal codice');

    expect(
      daDart,
      daXml,
      reason:
          'il canale usa #$daDart e Android userebbe #$daXml: la stessa '
          'notifica cambierebbe colore a seconda che l\'app sia aperta o no',
    );
  });
}
