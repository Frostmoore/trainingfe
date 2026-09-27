import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/auth/ui/widgets/social_buttons.dart';

/// 🎨 **Il marchio di Google c'è, ed è dichiarato** — 27/09/2026.
///
/// ══ 🚨 PERCHE' QUESTO TEST ESISTE ═══════════════════════════════════════════
///
/// Il pulsante ha una **rete di sicurezza**: se il file del marchio manca, invece
/// di far schiantare la schermata di accesso rimette una lettera. ⛔ Ma una rete
/// che salva **in silenzio** è la cosa che questo progetto ha già pagato troppe
/// volte: l'app andrebbe in produzione col ripiego, e nessuno se ne accorgerebbe
/// finché qualcuno non guarda il pulsante.
///
/// 🔑 **Questo test è la voce della rete.** Se il marchio non c'è, o non è
/// dichiarato nel `pubspec.yaml`, diventa rosso e lo dice.
///
/// ⚠️ E le due cose servono **tutte e due**: un file sul disco che non è
/// dichiarato nel `pubspec` **non finisce dentro l'app**. 💡 È già successo in
/// questo progetto il 15/09 con `assets/marchio/`: i PNG c'erano dal 28/08, ma li
/// leggevano solo i generatori, dal disco — dentro l'APK non ci finivano.
void main() {
  /// 🔎 I test girano dalla cartella dell'app, ma a volte dalla radice del
  /// progetto: si accettano tutti e due i punti di partenza invece di
  /// pretenderne uno, o il test cadrebbe per il posto da cui è stato lanciato.
  File dovunqueSia(String percorso) {
    final dentro = File("trainingfe/$percorso");

    return dentro.existsSync() ? dentro : File(percorso);
  }

  test("il marchio di Google esiste sul disco", () {
    final file = dovunqueSia(marchioGoogle);

    expect(
      file.existsSync(),
      isTrue,
      reason:
          "🚨 Manca $marchioGoogle: il pulsante di Google mostrerebbe il ripiego "
          "(una lettera), e in produzione nessuno se ne accorgerebbe. "
          "💡 Si rigenera con: bash memory/scripts/fai-la-g-di-google.sh",
    );

    expect(
      file.lengthSync(),
      greaterThan(1000),
      reason:
          "🚨 Il file c'è ma è troppo piccolo per essere il marchio: probabilmente "
          "la rasterizzazione è andata a vuoto e ha prodotto un PNG vuoto.",
    );
  });

  test("e il suo ORIGINALE vettoriale è conservato", () {
    /*
     * 🔑 Il PNG si può rigenerare **solo** se l'SVG di Google resta nel repo.
     * ⛔ Senza, il giorno che servisse un'altra misura qualcuno ingrandirebbe il
     * PNG — e un marchio sfocato è un marchio usato male.
     */
    final svg = dovunqueSia("assets/marchio/google_g.svg");

    expect(
      svg.existsSync(),
      isTrue,
      reason: "🚨 Manca l'SVG ufficiale: il PNG non si potrà più rigenerare.",
    );

    final testo = svg.readAsStringSync();

    /*
     * ⚠️ Si controllano i **quattro colori ufficiali**, non la dimensione del
     * file: sono la firma del marchio. ⛔ Se qualcuno lo «ritoccasse», questo
     * test cadrebbe — ed è esattamente quello che deve fare, perché ricolorare un
     * marchio registrato non si può.
     */
    for (final colore in const ["#EA4335", "#4285F4", "#FBBC05", "#34A853"]) {
      expect(
        testo.contains(colore),
        isTrue,
        reason:
            "🚨 Il colore $colore non c'è più nell'SVG: il marchio è stato "
            "modificato, e non si può.",
      );
    }
  });

  test("ed è dichiarato nel pubspec, o dentro l'app non ci finisce", () {
    final pubspec = dovunqueSia("pubspec.yaml");

    /*
     * ⚠️ **Si legge a mano invece di usare un parser YAML**, e non è pigrizia:
     * `yaml` non è fra le dipendenze del progetto, e ⛔ aggiungerne una per un
     * test solo è un costo che si paga a ogni aggiornamento.
     *
     * 💡 Qui basta guardare le righe sotto `assets:`, che è una struttura
     * semplice e stabile — e se un giorno smettesse di esserlo, questo test
     * diventerebbe rosso invece di mentire.
     */
    final righe = pubspec.readAsLinesSync();

    final inizio = righe.indexWhere((r) => r.trimRight() == "  assets:");

    expect(
      inizio,
      greaterThanOrEqualTo(0),
      reason: "🚨 Nel pubspec non c'è nessun blocco `assets:`.",
    );

    final dichiarati = <String>[];

    for (var i = inizio + 1; i < righe.length; i++) {
      final r = righe[i];

      // 💡 Righe vuote e commenti stanno dentro il blocco; la prima riga che non
      //    è una voce dell'elenco lo chiude.
      if (r.trim().isEmpty || r.trimLeft().startsWith("#")) continue;
      if (!r.trimLeft().startsWith("- ")) break;

      dichiarati.add(r.trim().substring(2).trim());
    }

    final coperto = dichiarati.any(
      (d) =>
          d == marchioGoogle ||
          (d.endsWith("/") && marchioGoogle.startsWith(d)),
    );

    expect(
      coperto,
      isTrue,
      reason:
          "🚨 $marchioGoogle non è dichiarato nel pubspec: il file c'è sul disco "
          "ma **dentro l'app non ci finisce**, e il pulsante mostrerà il ripiego. "
          "È già successo il 15/09 con gli altri file di assets/marchio/. "
          "Dichiarati: $dichiarati",
    );
  });
}
