import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/onboarding/data/gym_branding.dart';
import 'package:training_companion/src/features/onboarding/ui/widgets/marchio_in_cima.dart';

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
   * ⛔ L'unico posto dove leggere il nome è giusto.
   *
   * 🚨 Non è un'eccezione di comodo: lì la domanda è **«come si chiama?»**, non
   * «ce n'è una». Sulla schermata di accesso la palestra non si sa ancora, e
   * scrivere il nome dell'app è la cosa giusta da fare.
   */
  const leciti = {
    'lib/src/features/onboarding/data/gym_branding.dart',
    // 🆕 ⛔ **`gym_header.dart` non è più nell'elenco, e non è sparito il file:
    // era il QUINTO punto, ed è tornato a mordere il 14/09.** Il cerchio in cima
    // ad `/accedi` e `/registrati` mostrava una «T» a chi non ha nessuna
    // palestra, perché guardava il nome. 💡 Adesso è `MarchioInCima`, che usa
    // `haPalestra`: nessuna deroga da concedergli.
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

  // ─────────────────── e quello che si vede a schermo ───────────────────

  /// ⛔ **La guardia qui sopra cerca una forma di codice, non un risultato.**
  /// Il 14/09 il difetto è rientrato da una riga che lei non poteva vedere:
  /// `nome != null && nome.isNotEmpty`, con `nome` estratto in una variabile
  /// locale una riga prima. 💡 Questi due misurano invece **cosa legge una
  /// persona**, che è la cosa che il committente ha visto.
  testWidgets('senza palestra il marchio è l applicazione, non una «T»', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarchioInCima(branding: GymBranding.neutral)),
      ),
    );

    // 🚨 La «T» di «Training Companion» dentro il cerchio: è quella che
    // faceva sembrare l'app una palestra che non esiste.
    expect(find.text('T'), findsNothing);

    expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);

    // 💡 E il nome si scrive: `/benvenuto` è l'unica schermata che si vede
    // prima di avere un account.
    expect(find.text('Training Companion'), findsOneWidget);
  });

  /// ⚖️ **E la palestra vera non si perde per strada.** Togliere la «T» a tutti
  /// sarebbe stato altrettanto sbagliato: chi è iscritto a una palestra deve
  /// vedere la sua, non il manubrio.
  testWidgets('con una palestra si vede la sua iniziale e il suo nome', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarchioInCima(
            branding: GymBranding(
              name: 'Olympus Gym',
              slug: 'olympus',
              primary: Color(0xFF123456),
              secondary: Color(0xFF123456),
              accent: Color(0xFF123456),
            ),
          ),
        ),
      ),
    );

    expect(find.text('O'), findsOneWidget);
    expect(find.text('Olympus Gym'), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center_rounded), findsNothing);
  });
}
