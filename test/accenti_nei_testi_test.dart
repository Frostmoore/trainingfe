import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ✍️ **Niente apostrofi al posto degli accenti nei testi a schermo** —
/// 23/09/2026, dal giro UX.
///
/// ══ ⛔ IL DIFETTO ══════════════════════════════════════════════════════════
///
/// In «I tuoi dati» si leggeva *«Sono gia' compresi nel fattore del tuo livello
/// di attivita'»*, e in «Backup e dati» *«quello che c'e' nella copia … andra'
/// perso, e non si puo' annullare»*.
///
/// ⚠️ Cinque parole in tre schermate, tutte in frasi che spiegano qualcosa di
/// delicato: un ripristino che cancella, e il motivo per cui l'obiettivo
/// calorico non sale. 💡 Non cambia cosa fa l'app, cambia **quanto sembra
/// curata** — e chi legge «non si puo' annullare» prima di premere un pulsante
/// irreversibile merita una frase scritta bene.
///
/// ══ 💡 PERCHÉ UN TEST E NON UNA CORREZIONE E BASTA ════════════════════════
///
/// Perché è una svista che si rifà da sola: chi scrive una stringa Dart fra
/// apici singoli trova l'apostrofo comodo e l'accento scomodo, e lo stesso vale
/// per chi la scriverà domani. ⚠️ Correggerle senza un guardiano vuol dire
/// ritrovarne altre fra un mese.
///
/// ⛔ Si guardano **solo le righe di codice**: nei commenti l'apostrofo è usato
/// di proposito in tutto il progetto, e lì non lo legge nessun utente.
void main() {
  /// Le parole italiane che vogliono l'accento finale.
  ///
  /// 💡 `po` **non** c'è ed è voluto: *«un po'»* con l'apostrofo è corretto.
  const parole = [
    'piu', 'gia', 'attivita', 'perche', 'puo', 'cosi', 'citta', 'qualita',
    'liberta', 'meta', 'volonta', 'pero', 'sara', 'verra', 'potra', 'dovra',
    'andra', 'avra', 'stara', 'restera', 'finira', 'cioe', 'poiche', 'benche',
    'finche', 'servira', 'bastera', 'dara', 'fara', 'vorra', 'terra', 'ne',
    'e',
  ];

  test('nessun testo a schermo scrive «gia\'» invece di «già»', () {
    final colpevoli = <String>[];

    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) {
        continue;
      }

      final righe = f.readAsStringSync().split('\n');

      for (var i = 0; i < righe.length; i++) {
        final nuda = righe[i].trimLeft();

        if (nuda.startsWith('//') ||
            nuda.startsWith('*') ||
            nuda.startsWith('/*')) {
          continue;
        }

        for (final p in parole) {
          /*
           * 🚨 Si cerca la parola seguita da un apostrofo **con la barra
           * rovescia**: dentro una stringa Dart fra apici singoli è l'unico
           * modo di scriverlo, ed è il segno che qualcuno voleva l'accento.
           *
           * 💡 Così una chiave come `obiettivo.livello_attivita` o una rotta
           * come `/account/citta` non fanno rumore: lì l'apice chiude la
           * stringa e la barra non c'è.
           */
          if (RegExp("(?<![a-zA-Z_])$p\\\\'").hasMatch(righe[i])) {
            colpevoli.add('${f.path}:${i + 1}  [$p]  ${righe[i].trim()}');
            break;
          }
        }
      }
    }

    expect(colpevoli, isEmpty, reason: '\n${colpevoli.join('\n')}');
  });
}
