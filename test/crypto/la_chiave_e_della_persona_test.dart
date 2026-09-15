import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/crypto/portachiavi.dart';

/// La chiave maestra è **della persona**, non del telefono — 15/09/2026.
///
/// ══ ⛔ IL DIFETTO ══════════════════════════════════════════════════════════
///
/// La chiave stava sotto un nome fisso, uguale per chiunque usasse quel
/// telefono, e `logout()` non la cancellava. Sullo stesso dispositivo la
/// seconda persona che entrava **ereditava la chiave della prima**:
///
///   - non le veniva mai chiesta la password di recupero, perché
///     `ServizioChiavi.stato()` trovava una chiave e rispondeva `pronto`;
///   - i suoi messaggi venivano chiusi con la chiave di un'altra persona;
///   - sul server non compariva nessuna chiave sua, quindi chi le scriveva
///     leggeva *«questa persona non ha ancora una chiave»*.
///
/// 🚨 E il danno grosso è il primo: chi si ritrova quel telefono — usato,
/// prestato, rivenduto — ha in mano la chiave che apre i messaggi, le schede e i
/// piani di chi c'era prima.
///
/// ⚠️ **Visto sull'emulatore il 15/09**, facendo una chat fra un trainer e
/// un'allieva: alla seconda persona la password non è stata chiesta.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  final chiaveDiAnna = Uint8List.fromList(List.filled(32, 1));
  final chiaveDiBruno = Uint8List.fromList(List.filled(32, 2));

  test('due persone sullo stesso telefono non si incontrano', () async {
    final anna = Portachiavi(utenteId: 1);
    await anna.salvaChiaveMaestra(chiaveDiAnna);

    // 🚨 Bruno entra **dopo**, sullo stesso telefono: prima leggeva la chiave
    // di Anna e non gli veniva chiesto niente.
    final bruno = Portachiavi(utenteId: 2);

    expect(await bruno.chiaveMaestra(), isNull);

    await bruno.salvaChiaveMaestra(chiaveDiBruno);

    expect(await bruno.chiaveMaestra(), chiaveDiBruno);

    // ⚖️ E Anna non ha perso la sua: sono due slot, non uno conteso.
    expect(await Portachiavi(utenteId: 1).chiaveMaestra(), chiaveDiAnna);
  });

  /// ⚖️ **Il guadagno dell'altra strada.** Si era valutato di cancellare la
  /// chiave all'uscita: chiudeva la falla uguale, ma costava una password di
  /// recupero a **ogni** rientro. Con lo slot per persona, chi esce e rientra
  /// ritrova la sua.
  test('chi esce e rientra ritrova la sua chiave', () async {
    await Portachiavi(utenteId: 7).salvaChiaveMaestra(chiaveDiAnna);

    expect(await Portachiavi(utenteId: 7).chiaveMaestra(), chiaveDiAnna);
  });

  test('dimenticare la chiave tocca solo la propria', () async {
    await Portachiavi(utenteId: 1).salvaChiaveMaestra(chiaveDiAnna);
    await Portachiavi(utenteId: 2).salvaChiaveMaestra(chiaveDiBruno);

    await Portachiavi(utenteId: 1).dimenticaChiave();

    expect(await Portachiavi(utenteId: 1).chiaveMaestra(), isNull);
    expect(await Portachiavi(utenteId: 2).chiaveMaestra(), chiaveDiBruno);
  });

  // ─────────────── quando non si sa ancora chi è entrato ───────────────

  /// ⚠️ Succede davvero: fra l'avvio dell'app e la risposta di `/auth/me`.
  ///
  /// 🚨 I due versi sbagliano **in direzioni diverse di proposito**: in lettura
  /// si risponde `null`, e al massimo si chiede una password di troppo; in
  /// scrittura si lancia, perché una chiave salvata sotto il nome sbagliato è
  /// una chiave persa.
  test('senza un utente non si legge', () async {
    await Portachiavi(utenteId: 1).salvaChiaveMaestra(chiaveDiAnna);

    expect(await Portachiavi(utenteId: null).chiaveMaestra(), isNull);
  });

  test('e soprattutto non si scrive', () async {
    expect(
      () => Portachiavi(utenteId: null).salvaChiaveMaestra(chiaveDiAnna),
      throwsA(isA<StateError>()),
    );
  });

  // ─────────────── la chiave vecchia, quella di nessuno ───────────────

  /// ⛔ **Non si eredita, si butta.**
  ///
  /// 🚨 Indovinare di chi fosse sarebbe esattamente il difetto che questa
  /// classe è stata riscritta per chiudere: l'unico modo onesto sarebbe
  /// confrontare la chiave pubblica che ne deriva con quella pubblicata dal
  /// server per **questo** account.
  ///
  /// ⚠️ Il prezzo è dichiarato: chi aveva l'app prima del 15/09 ridigita la
  /// password di recupero una volta. Il pacchetto sta sul server, quindi non
  /// perde niente.
  test('la chiave senza proprietario non passa a chi capita', () async {
    FlutterSecureStorage.setMockInitialValues({
      'chiave_maestra': 'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=',
    });

    final chiunque = Portachiavi(utenteId: 99);

    expect(await chiunque.chiaveMaestra(), isNull);
  });

  /// ⚖️ **E leggere non la distrugge**, che è il momento sbagliato.
  ///
  /// ⛔ La prima stesura la cancellava appena qualcuno provava a leggere: così
  /// la chiave vecchia spariva **prima** che la persona avesse ridigitato la
  /// password di recupero, e chi non se la ricordava non aveva più nessun modo
  /// di tornare indietro.
  ///
  /// 💡 La falla la chiude il **non leggerla** — il test qui sopra — non il
  /// cancellarla.
  test('leggere non la distrugge: quello viene dopo', () async {
    FlutterSecureStorage.setMockInitialValues({
      'chiave_maestra': 'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=',
    });

    await Portachiavi(utenteId: 99).chiaveMaestra();

    const magazzino = FlutterSecureStorage();

    expect(await magazzino.read(key: 'chiave_maestra'), isNotNull);
  });

  /// 💡 Si butta quando non serve più a nessuno: cioè quando una chiave ha
  /// già trovato uno slot con un nome sopra.
  test('sparisce quando una chiave nuova ha trovato casa', () async {
    FlutterSecureStorage.setMockInitialValues({
      'chiave_maestra': 'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=',
    });

    await Portachiavi(utenteId: 99).salvaChiaveMaestra(chiaveDiBruno);

    const magazzino = FlutterSecureStorage();

    expect(await magazzino.read(key: 'chiave_maestra'), isNull);
  });
}
