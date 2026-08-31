import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/acquisti/data/costo_delle_funzioni.dart';

/// Il prezzo sui pulsanti viene da una sede sola — 3b-AE, 31/08/2026.
///
/// ══ 📌 LA REGOLA ══════════════════════════════════════════════════════════
///
/// 📌 Il committente, da 3b-I: *«il tasto deve avere scritto che costa 1
/// gettone»*.
///
/// 🚨 **È l'unico posto onesto per scriverlo**: chi tocca sta spendendo, e
/// leggerlo *dopo* nel saldo è il modo per non fidarsi più di nessun altro
/// pulsante dell'app.
///
/// ══ ⛔ E PERCHÉ QUESTO FILE SCANDAGLIA IL SORGENTE ════════════════════════
///
/// Finché il pulsante con un prezzo era **uno**, scriverlo a mano andava bene.
/// Da 3b-AE sono **quattro** — stima da testo, foto, analisi della scheda,
/// «Rigenera» — e un numero copiato in quattro etichette è un numero che un
/// giorno mente in tre.
///
/// ⚠️ **Un prezzo che mente su un pulsante è peggio di un prezzo assente**: chi
/// legge «1 gettone» e ne vede sparire dieci non torna a leggere l'etichetta,
/// smette di fidarsi dell'app.
void main() {
  group('«N gettone/i» non si scrive a mano', () {
    /// ⚠️ Si cerca nel **codice**, non nei commenti: i commenti che spiegano la
    /// regola la citano, e un test ingenuo accuserebbe la propria spiegazione.
    /// 💡 È la stessa trappola già pagata in `impostazioni_riordinate_test`.
    String soloCodice(String sorgente) => sorgente
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .split('\n')
        .where((r) => !r.trimLeft().startsWith('///'))
        .where((r) => !r.trimLeft().startsWith('//'))
        .join('\n');

    test('nessun file scrive il prezzo dentro un\'etichetta', () {
      final colpevoli = <String>[];

      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;

        // ⛔ La sede unica ovviamente li contiene: è il suo mestiere.
        if (f.path.endsWith('costo_delle_funzioni.dart')) continue;

        final codice = soloCodice(f.readAsStringSync());

        if (RegExp(r"\d+ getton[ei]").hasMatch(codice)) {
          colpevoli.add(f.path);
        }
      }

      expect(
        colpevoli,
        isEmpty,
        reason:
            'Il prezzo è scritto a mano qui dentro. Usa `costoDi(AiACosa.…)`: '
            'una copia diverge, e quella che diverge è quella che il cliente '
            'legge.',
      );
    });
  });

  group('come si scrive un prezzo', () {
    test('uno è singolare', () {
      /*
       * 💡 Sembra pedanteria e non lo è: «1 gettoni» su un pulsante è la cosa
       * che chi legge nota **prima** del prezzo, e da lì in poi guarda l'app
       * con un occhio diverso.
       */
      expect(costoDi(AiACosa.cibo), '1 gettone');
    });

    test('gli altri sono plurali', () {
      expect(costoDi(AiACosa.foto), '10 gettoni');
      expect(costoDi(AiACosa.pdf), '50 gettoni');
    });
  });

  group('i prezzi sono quelli del server', () {
    /*
     * ══ 🚨 QUESTA È UNA COPIA, E IL TEST LO DICHIARA ═══════════════════════
     *
     * La fonte di verità è `AiFeature::costoInGettoni()` sul server: è lui che
     * scala i gettoni. ⚠️ Qui c'è una copia per poter scrivere il prezzo sul
     * pulsante **prima** di chiamare.
     *
     * ⛔ Un test non può interrogare il server, quindi questi numeri non
     * provano l'allineamento: lo **fissano**. Se qualcuno li cambia di qua
     * senza cambiarli di là, questo test diventa rosso e obbliga a guardare —
     * che è tutto quello che un test può fare da questa parte del filo.
     */
    test('e se cambiano di là, questo test va aggiornato a mano', () {
      expect(AiACosa.cibo.gettoni, 1);
      expect(AiACosa.foto.gettoni, 10);
      expect(AiACosa.scheda.gettoni, 1);
      expect(AiACosa.consiglio.gettoni, 1);

      // 📌 *«L'import dei pdf costa SEMPRE 50 gettoni, abbonato o no»* — U.6.
      expect(AiACosa.pdf.gettoni, 50);
    });
  });
}
