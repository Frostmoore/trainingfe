import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🔄 **Ogni segnale di «rileggi» dev'essere nell'elenco** — 23/09/2026.
///
/// ══ ⛔ IL GUASTO ═══════════════════════════════════════════════════════════
///
/// Entrato come **un'altra persona** sullo stesso telefono, la schermata «Oggi»
/// del nuovo arrivato mostrava **8 kcal bruciate e 363% di carico**: i numeri di
/// chi c'era prima. 🚨 L'archivio era già stato svuotato — database vuoto,
/// controllato tabella per tabella — e quello che restava era il **ricordo dei
/// provider**, che avevano letto e non avevano motivo di rileggere.
///
/// ══ 💡 PERCHÉ QUESTO TEST ESISTE ══════════════════════════════════════════
///
/// `tuttoDaRileggere()` deve incrementare **tutti** i segnali `revisione…`. ⚠️
/// Sono `StateProvider<int>`: non c'è modo di enumerarli dall'interno come si fa
/// con `allTables` in `ArchivioSalute`. L'elenco a mano lì è **obbligato**.
///
/// 🚨 E un elenco a mano che deve contenere tutto, in questo progetto, si è già
/// rotto tre volte: due su `svuota()` (le tabelle degli allenamenti nel 25/08,
/// undici tabelle il 23/09) e una sulle preferenze del backup.
///
/// 💡 Quindi l'elenco resta a mano, ma **non può marcire**: questo test legge i
/// sorgenti, trova ogni `revisione…Provider` dichiarato in `lib/` e pretende che
/// compaia nell'elenco. Un segnale nuovo fa diventare rosso il test il giorno
/// stesso in cui nasce, senza che nessuno debba ricordarsi di niente.
void main() {
  test('tuttoDaRileggere() incrementa ogni segnale di revisione', () {
    final dichiarati = <String, String>{};

    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) {
        continue;
      }

      for (final m in RegExp(
        r'^final (revisione\w*Provider)\s*=\s*StateProvider',
        multiLine: true,
      ).allMatches(f.readAsStringSync())) {
        dichiarati[m.group(1)!] = f.path;
      }
    }

    expect(
      dichiarati,
      isNotEmpty,
      reason: 'il test non prova niente se non trova nessun segnale',
    );

    final elenco = File(
      'lib/src/core/stato/tutto_da_rileggere.dart',
    ).readAsStringSync();

    final mancanti = dichiarati.entries
        .where((e) => !elenco.contains(e.key))
        .map((e) => '${e.key}  (${e.value})')
        .toList();

    expect(
      mancanti,
      isEmpty,
      reason:
          '\nQuesti segnali non vengono incrementati quando entra un\'altra '
          'persona,\nquindi i suoi dati resterebbero a schermo:\n'
          '${mancanti.join('\n')}',
    );
  });
}
