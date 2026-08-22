import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// «C'è una palestra?» si chiede a `haPalestra`, mai al nome — difetto O.D.2,
/// **secondo giro**, 22/08/2026.
///
/// ══ 🚨 LO STESSO DIFETTO, TROVATO DUE VOLTE ═══════════════════════════════
///
/// Il 21/08 il controllo `name != null && name!.isNotEmpty` è stato corretto in
/// **quattro** punti: `GymBranding.neutral` ha `name: 'Training Companion'`,
/// quindi rispondeva «sì, c'è una palestra» a chi non ne ha.
///
/// ⛔ **Ne era rimasto un quinto**, e il motivo per cui è sopravvissuto è
/// stupido: era spezzato su sei righe, e il `grep` cercava
/// `name?.isNotEmpty ?? false` **su una riga sola**.
///
/// 🚨 Il risultato l'ha visto il committente: *«non mi hai messo nessuna
/// interfaccia per selezionare il colore di accento»*. C'era — ed era
/// invisibile a tutti, perché nascosta dietro quel controllo.
///
/// 💡 Questo test **normalizza gli spazi prima di cercare**, quindi gli a capo
/// non lo ingannano. È l'unica differenza fra lui e il grep che ha fallito.
void main() {
  /*
   * ⛔ I due posti dove leggere il nome è giusto.
   *
   * 🚨 Non sono eccezioni di comodo: lì la domanda è **«come si chiama?»**, non
   * «ce n'è una». Sulla schermata di accesso la palestra non si sa ancora, e
   * scrivere il nome dell'app è la cosa giusta da fare.
   */
  const leciti = {
    'lib/src/features/onboarding/data/gym_branding.dart',
    'lib/src/features/auth/ui/widgets/gym_header.dart',
  };

  test('nessuno chiede al NOME se esiste una palestra', () {
    /*
     * Cerca `name` seguito da un controllo di presenza entro pochi caratteri:
     * `name != null`, `name?.isNotEmpty`, `name!.isNotEmpty`.
     */
    final sospetto = RegExp(
      r'\bname\s*(!=\s*null|[?!]?\.isNotEmpty|[?!]?\.isEmpty)',
    );

    final colpevoli = <String>[];

    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;

      final percorso = file.path.replaceAll(r'\', '/');
      if (leciti.contains(percorso)) continue;

      /*
       * ══ 🚨 CORRETTO IL 22/08/2026: L'ORDINE ERA ROVESCIATO ══════════════
       *
       * ⛔ **Questa guardia diceva sempre di sì.** Compattava gli a capo
       * **prima** di togliere i commenti: dopo il collasso non esistono più a
       * capo, quindi `// [^\n]*` divorava dal primo commento di riga fino alla
       * **fine del file**. Il test cercava dentro una stringa quasi vuota, e
       * passava per costruzione.
       *
       * ⚠️ Il 21/08 ha funzionato **per fortuna**: nel file colpevole il punto
       * incriminato veniva prima di qualunque commento `// `. 🚨 Una guardia
       * che funziona per fortuna è peggio di nessuna guardia, perché ci si
       * conta sopra.
       *
       * 💡 Adesso: prima via i commenti — con `dotAll` per quelli su più righe
       * e una passata apposta per i `///` — e solo dopo si compatta.
       *
       * ⚠️ Gli a capo vanno comunque tolti **prima di cercare**: è la
       * differenza fra questo test e il grep che il 21/08 non ha trovato il
       * quinto punto.
       */
      final codice = file
          .readAsStringSync()
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ')
          .replaceAll(RegExp(r'^\s*///.*$', multiLine: true), ' ')
          .replaceAll(RegExp('//[^\n]*'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ');

      for (final trovato in sospetto.allMatches(codice)) {
        final intorno = codice.substring(
          (trovato.start - 40).clamp(0, codice.length),
          (trovato.end + 10).clamp(0, codice.length),
        );

        // 💡 Interessa solo il nome **del branding**: `utente.name`,
        // `scheda.name` e gli altri non c'entrano niente.
        if (!intorno.contains('branding') && !intorno.contains('palestra')) {
          continue;
        }

        colpevoli.add('$percorso: …$intorno…');
      }
    }

    expect(
      colpevoli,
      isEmpty,
      reason:
          'Usa `GymBranding.haPalestra`. Il nome non risponde a quella '
          'domanda: `neutral` ne ha uno, e vale «Training Companion».',
    );
  });
}
