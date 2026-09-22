import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/chiavi/ui/ripristino_da_file.dart';

/// ♻️ **Il ripristino si raggiunge da «Backup e dati»** — 23/09/2026.
///
/// 📌 Il committente: *«non capisco perché per ripristinare il backup devo
/// andare sui messaggi e non su "backup e dati"»*. Prima il ripristino da file
/// viveva solo dentro `SchermataRipristino` — dietro alla chat, e raggiungibile
/// soltanto quando l'app si accorgeva da sola che la chiave mancava.
///
/// ⛔ Chi aveva già la chiave e voleva riprendersi peso, misure e diario non
/// aveva **nessuna** strada.
void main() {
  group('il dialogo che chiede file e codice', () {
    /// 🚨 Il pulsante resta spento finché i tre campi non stanno in piedi:
    /// un ripristino avviato con un codice monco fallisce dopo venti secondi
    /// di argon2id, e sembra che il file sia rotto.
    testWidgets('non si parte con i campi a metà', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ChiediFileECodice())),
      );

      FilledButton bottone() =>
          tester.widget<FilledButton>(find.byType(FilledButton));

      expect(bottone().onPressed, isNull, reason: 'acceso a campi vuoti');

      await tester.enterText(
        find.widgetWithText(TextField, 'Percorso del file'),
        '/storage/emulated/0/backup.json',
      );
      await tester.pump();
      expect(bottone().onPressed, isNull, reason: 'basta il percorso?');

      // ⚠️ 24 caratteri **normalizzati**: i trattini non contano.
      await tester.enterText(
        find.widgetWithText(TextField, 'Codice di ripristino'),
        'ABCD-EFGH-JKLM-NPQR-STUV-WXYZ',
      );
      await tester.pump();
      expect(bottone().onPressed, isNull, reason: 'manca la password');

      await tester.enterText(
        find.widgetWithText(TextField, 'Nuova password di recupero'),
        'corta',
      );
      await tester.pump();
      expect(bottone().onPressed, isNull, reason: 'password sotto gli 8');

      await tester.enterText(
        find.widgetWithText(TextField, 'Nuova password di recupero'),
        'Password-Nuova-9',
      );
      await tester.pump();
      expect(bottone().onPressed, isNotNull);
    });
  });

  group('le due porte, una sola strada', () {
    /// 💡 Si legge il sorgente, come fa `orientamento_verticale_test`: qui
    /// interessa **che non esistano due ripristini**, e quello non si vede
    /// pompando un widget.
    final backup = File(
      'lib/src/features/chiavi/ui/schermata_backup.dart',
    ).readAsStringSync();

    final chiavi = File(
      'lib/src/features/chiavi/ui/schermata_ripristino.dart',
    ).readAsStringSync();

    test('«Backup e dati» offre il ripristino da file', () {
      expect(backup, contains('Ripristina da un file'));
      expect(backup, contains('eseguiIlRipristinoDaFile'));
    });

    /// 🚨 **E qui si difende la conferma.** Da questa schermata la chiave c'è
    /// già: aprire un file vecchio la sostituisce, e i messaggi ricevuti da
    /// allora non si riaprono più. Togliere la domanda renderebbe irreversibile
    /// un tocco distratto.
    test('e prima chiede conferma, perché la chiave c\'è già', () {
      expect(backup, contains('Aprire un file di backup?'));
    });

    /// ⛔ La riga che impedisce il ritorno del difetto: se un domani qualcuno
    /// ricopia la logica dentro una schermata, qui si accorge.
    ///
    /// ⚠️ Si guarda `importaQualsiasi` — il gesto di **aprire il file** — e non
    /// `ripristinaDaChiave`: quella la usa legittimamente anche «Ricomincia»,
    /// che non apre niente e genera una chiave nuova di zecca.
    test('nessuna delle due si è fatta la sua copia', () {
      for (final sorgente in [backup, chiavi]) {
        expect(sorgente, contains('eseguiIlRipristinoDaFile'));
        expect(
          sorgente,
          isNot(contains('importaQualsiasi')),
          reason: 'aprire il file sta in ripristino_da_file.dart, non qui',
        );
      }
    });
  });
}
