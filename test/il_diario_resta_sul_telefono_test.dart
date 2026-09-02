import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Nessuno rimette il diario alimentare sul server — Parte I, I2.5.
///
/// ══ 🚨 COSA SORVEGLIA, E PERCHE' UN TEST SUL SORGENTE ════════════════════
///
/// 📌 Regola R3 del progetto: *«tutto ciò che è anche lontanamente sensibile
/// resta sul telefono»*. ⛔ Cosa mangia una persona è dato dell'art. 9, ed era
/// l'ultima tabella grossa di dati personali rimasta di là.
///
/// ⚠️ Il rischio non è che qualcuno lo rimetta apposta: è che una schermata
/// nuova, scritta fra sei mesi copiando una vecchia, chiami `POST /food-entries`
/// perché quella rotta **sul server esiste ancora** (sparisce con I4). 🚨 Il
/// risultato sarebbe una voce scritta di là e invisibile di qua — nessun errore,
/// e la scoperta solo riguardando il diario dopo.
///
/// 💡 Un test sui provider proverebbe che *quelle* letture sono giuste oggi.
/// Questo guarda **tutte** le chiamate, comprese quelle non ancora scritte.
///
/// ══ 📌 HA PRESO IL POSTO DI `serie_giorni_ammessi_test.dart` ═════════════
///
/// Quello sorvegliava i periodi che `/series` accettava, e ha fatto scuola in
/// tutti e due i sensi: ha spiegato la carica calcolata senza le calorie
/// (21/08), e **restava verde** mentre `tdeeMisuratoProvider` chiedeva 60 giorni
/// e prendeva un 422 — perché cercava i *letterali* `'days': N` e lì c'era una
/// costante. 🚨 Da I2.5 la serie si costruisce sul telefono e quel vincolo non
/// esiste più: al suo posto si sorveglia qualcosa che vale di più.

/// Le rotte del diario, che sul server esistono ancora ma non si chiamano più.
///
/// ⚠️ **`/foods/search` NON è in elenco, ed è deliberato**: il catalogo alimenti
/// resta sul server (non è di nessuno), e cercarci dentro non racconta cosa si è
/// mangiato — dice solo che si sta scrivendo una parola.
///
/// ⚠️ **`/ai/food/valida` nemmeno**: è il setaccio su una risposta del modello,
/// e deve restare di là. Vedi la nota su `DiaryActions.confermaStima`.
const rotteDelDiario = <String>[
  '/diary',
  '/food-entries',
  '/food-favorites',
  '/series',
  '/ai/food/confirm',
];

void main() {
  test('nessun file di lib chiama le rotte del diario', () {
    final sorgenti = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    final colpevoli = <String>[];

    for (final file in sorgenti) {
      final testo = file.readAsStringSync();

      for (final rotta in rotteDelDiario) {
        /*
         * 🚨 Si cerca la rotta **fra apici**, cioè come argomento di una
         * chiamata. ⛔ Senza gli apici scatterebbe su ogni commento che la
         * nomina — e questi file ne sono pieni, perché spiegano proprio cosa è
         * stato tolto.
         */
        if (testo.contains("'$rotta'") || testo.contains('"$rotta"')) {
          colpevoli.add('${file.path}: $rotta');
        }
      }
    }

    expect(
      colpevoli,
      isEmpty,
      reason:
          'Il diario alimentare vive sul telefono da I2.5: si legge e si scrive '
          'con DiarioLocale, non con queste rotte.',
    );
  });
}
