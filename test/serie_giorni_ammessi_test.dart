import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/dashboard/dashboard_controller.dart';

/// Ogni chiamata a `/series` chiede un numero di giorni che il server accetta —
/// difetto del 21/08/2026.
///
/// ══ 🚨 IL DIFETTO CHE QUESTO FILE ESISTE PER NON RIVEDERE ═════════════════
///
/// `_storiaCalorieProvider` chiedeva `days: 28` — la finestra dei calcoli di
/// forma. ⚠️ Ma `SeriesController::index` valida `days` con
/// `in:0,7,30,90,365`: sono i **periodi dei pulsanti del grafico**, non un
/// intervallo libero. Il server rispondeva `422 validation.in`.
///
/// 🚨 **E non se ne accorgeva nessuno.** Il chiamante aveva un `catch` che
/// scriveva una riga di log e proseguiva, quindi la **carica veniva calcolata
/// senza l'ingrediente delle calorie**: nessun errore a schermo, un numero
/// plausibile, e nessun modo di vederlo dall'app. È saltato fuori solo perché
/// un crollo di layout ha costretto a leggere il log per un altro motivo.
///
/// ── 💡 Perché un test che legge il sorgente ───────────────────────────────
///
/// Un test sul provider proverebbe che *quella* chiamata è giusta oggi. ⚠️ Il
/// difetto però è di **categoria**: il numero ammesso vive sul server, e chi
/// scrive una nuova chiamata qui non ha nessun modo di saperlo. 🚨 Questo test
/// guarda **tutte** le chiamate, comprese quelle non ancora scritte, e fallisce
/// prima che il difetto arrivi sul telefono.
///
/// ⚠️ Se un giorno il server amplia l'elenco, va ampliato **anche qui**: due
/// copie della stessa regola sono il prezzo di poterla controllare senza rete,
/// ed è il motivo per cui il percorso del file di là è scritto qui sotto.
/// L'elenco di `SeriesController::GIORNI_AMMESSI`, in
/// `trainingbe/app/Http/Controllers/Api/V1/Training/SeriesController.php`.
const ammessi = {0, 7, 30, 90, 365};

void main() {
  test('nessun letterale in lib chiede giorni che il server rifiuta', () {
    final sorgenti = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    /*
     * Due forme, e sono le due che esistono davvero nel progetto:
     *  - `'days': 28` — la query mandata a `/series`;
     *  - `CaloriesWindow(days: 28)` — la finestra che poi finisce nella query.
     *
     * 🚨 La seconda serve perché **non sta nello stesso file** della chiamata:
     * i pulsanti del periodo vivono in `dashboard_screen.dart`, e un test che
     * guardasse solo i file con dentro `'/series'` non li vedrebbe.
     */
    final regole = [
      RegExp(r"'days'\s*:\s*(-?\d+)"),
      RegExp(r'CaloriesWindow\(\s*days:\s*(-?\d+)'),
    ];

    final colpevoli = <String>[];

    for (final file in sorgenti) {
      final testo = file.readAsStringSync();

      for (final regola in regole) {
        for (final trovato in regola.allMatches(testo)) {
          final giorni = int.parse(trovato.group(1)!);

          if (!ammessi.contains(giorni)) {
            colpevoli.add('${file.path}: days: $giorni');
          }
        }
      }
    }

    expect(
      colpevoli,
      isEmpty,
      reason:
          'Il server accetta solo $ammessi giorni. '
          'Chiedi il valore ammesso più vicino e taglia la lista in casa.',
    );
  });

  test('la costante dell app dice le stesse cose del server', () {
    expect(giorniAmmessiPerLeSerie, ammessi);
  });

  test('una finestra non ammessa spacca subito, invece di dare 422', () {
    // 🚨 È il punto del difetto: senza questo `assert` un numero sbagliato
    // arrivava al server, tornava `422`, e qualcuno lo intercettava in
    // silenzio. ⚠️ Meglio un errore rumoroso in sviluppo.
    expect(() => CaloriesWindow(days: 28), throwsA(isA<AssertionError>()));

    for (final g in ammessi) {
      expect(CaloriesWindow(days: g).days, g);
    }
  });
}
