import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🚨 Nessuna lettura di salute senza il consenso — 08/09/2026.
///
/// ══ ⛔ PERCHE' QUESTO TEST ESISTE ═════════════════════════════════════════
///
/// Il registro dei trattamenti, T17: *«Base giuridica: art. 9(2)(a) — consenso
/// esplicito … verificato **prima di ogni lettura**»*.
///
/// 🚨 **L'08/09 quell'affermazione era falsa**, e non per una svista grande.
/// `PonteSalute` il consenso lo controllava, ma i due canali nativi nuovi — il
/// dislivello e il percorso — parlano con Health Connect **senza passare di
/// lì**: una porta nuova aperta accanto a quella sorvegliata.
///
/// ⚠️ **Il permesso di Android non lo sostituisce**: quello dice cosa il sistema
/// ci lascia leggere, non cosa la persona ha acconsentito che noi trattiamo.
///
/// 💡 Questo test cerca la regola in **tutti** i file invece che in uno, come
/// `prontezza_non_e_una_carica_test`: è l'unico modo di accorgersi di una porta
/// che qualcuno aprirà domani in un posto che oggi non stiamo guardando.
void main() {
  /// Tutti i `.dart` sotto `lib/`.
  List<File> sorgenti() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('⛔ chi legge dal canale nativo controlla il consenso', () {
    /*
     * ⚠️ **Si guardano i file, non le chiamate**: un file che usa `SaluteInPiu`
     * per leggere e non nomina mai il consenso è il caso da fermare. 🚨 Non è
     * una prova formale — un `if` scritto male passa lo stesso — ma coglie
     * l'errore vero, che è **dimenticarsene**.
     */
    final colpevoli = <String>[];

    for (final file in sorgenti()) {
      final testo = file.readAsStringSync();

      // 💡 Il file che DEFINISCE il canale non legge niente da solo.
      if (file.path.endsWith('salute_in_piu.dart')) continue;

      final legge =
          testo.contains('.dislivelloFra(') || testo.contains('.percorso(');

      if (!legge) continue;

      if (!testo.contains('consensoSaluteProvider')) {
        colpevoli.add(file.path);
      }
    }

    expect(
      colpevoli,
      isEmpty,
      reason:
          'questi file leggono dati di salute dal canale nativo senza '
          'controllare il consenso: $colpevoli',
    );
  });

  test('🚨 e il consenso ha un posto solo in cui è scritto', () {
    /*
     * ⛔ **Due implementazioni della stessa regola divergono sempre**, ed è già
     * scritto su `healthControllerProvider`: *«La regola vive tutta in
     * `consensoSaluteProvider`»*.
     *
     * 💡 Qui si difende che resti una: se un domani qualcuno scrivesse un
     * secondo controllo leggendo la data del consenso a mano, questo test lo
     * troverebbe.
     */
    final definizioni = sorgenti()
        .where(
          (f) => f.readAsStringSync().contains('final consensoSaluteProvider'),
        )
        .map((f) => f.path)
        .toList();

    expect(definizioni, hasLength(1));
  });
}
