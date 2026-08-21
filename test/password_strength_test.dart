import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/auth/data/password_strength.dart';

/// Il giudizio sulle password.
///
/// 🚨 Quello che si prova qui **non è la sicurezza** — quella la decide il
/// backend — ma che i consigli siano *utili e onesti*. Un indicatore che dice
/// «ottima» a `riccardo1234` insegna a fidarsi di lui, ed è peggio di non
/// averlo: dopo tre volte che approva una password debole, nessuno lo guarda
/// più.
void main() {
  PasswordStrength v(
    String p, {
    String? nome,
    String? email,
    String? username,
  }) =>
      PasswordStrength.valuta(p, nome: nome, email: email, username: username);

  group('la lunghezza è la variabile che conta', () {
    test('sotto il minimo non si passa, e si dice quanto manca', () {
      final forza = v('Ab1c');

      expect(forza.score, 0);
      expect(forza.accettabile, isFalse);
      expect(forza.suggerimenti.first, contains('8'));
    });

    test('una passphrase lunga e semplice batte una corta e complicata', () {
      final lunga = v('cavallo divano lampada 7');
      final corta = v('P4ss!w0');

      expect(
        lunga.score,
        greaterThan(corta.score),
        reason:
            'È il punto di tutta la classe: la composizione forzata '
            'produce password prevedibili, la lunghezza no.',
      );
      expect(lunga.accettabile, isTrue);
    });

    test('sotto i dodici caratteri il primo consiglio è allungarla', () {
      final forza = v('Kq7mzP1a');

      expect(forza.accettabile, isTrue);
      expect(forza.suggerimenti.first.toLowerCase(), contains('allungala'));
    });
  });

  group('le password che si indovinano subito', () {
    test('una password di lista va a zero, non «un po\' meno»', () {
      final forza = v('password');

      expect(
        forza.score,
        0,
        reason:
            'Una password nelle liste si indovina in un istante qualunque '
            'sia la sua lunghezza: non esiste punteggio parziale.',
      );
      expect(forza.suggerimenti.first, contains('liste'));
    });

    test('aggiungere un numero in fondo non la salva', () {
      expect(v('qwerty123').score, 0);
      expect(v('password1').score, 0);
    });

    test('le sequenze si riconoscono e si spiegano', () {
      final forza = v('mareabcd99');

      expect(forza.suggerimenti.any((s) => s.contains('sequenze')), isTrue);
    });

    test('le lettere ripetute contano come sequenza', () {
      expect(
        v('marooooo12').suggerimenti.any((s) => s.contains('sequenze')),
        isTrue,
      );
    });

    test('tre caratteri in fila NON bastano a far scattare l\'avviso', () {
      // Una soglia troppo bassa segnalerebbe password buone, e un avviso che
      // scatta sempre è un avviso che si impara a ignorare.
      final forza = v('tavolabc95kq');

      expect(forza.suggerimenti.any((s) => s.contains('sequenze')), isFalse);
    });
  });

  group(
    '🚨 i dati personali, che è il motivo per cui il controllo sta qui',
    () {
      test('il proprio nome dentro la password viene detto subito', () {
        final forza = v('riccardo1234', nome: 'Riccardo Ronconi');

        expect(forza.score, lessThanOrEqualTo(1));
        expect(forza.suggerimenti.first, contains('il tuo nome'));
      });

      test('vale anche per il cognome da solo', () {
        final forza = v('ronconi2026!', nome: 'Riccardo Ronconi');

        expect(forza.suggerimenti.first, contains('il tuo nome'));
      });

      test('e per il nome utente e la parte locale dell\'email', () {
        expect(
          v('mariorossi88', username: 'mariorossi').suggerimenti.first,
          contains('nome utente'),
        );
        expect(
          v('geometra88xy', email: 'geometra@esempio.test').suggerimenti.first,
          contains('email'),
        );
      });

      test('⚠️ un nome corto non fa scattare falsi allarmi', () {
        // «Ada» comparirebbe dentro «adattamento»: sotto i 4 caratteri il
        // confronto darebbe più fastidio che protezione.
        final forza = v('adattamento47', nome: 'Ada');

        expect(
          forza.suggerimenti.any((s) => s.contains('il tuo nome')),
          isFalse,
        );
      });

      test('senza dati personali non si inventa un problema', () {
        final forza = v('riccardo1234');

        expect(
          forza.suggerimenti.any((s) => s.contains('il tuo nome')),
          isFalse,
        );
      });
    },
  );

  group('la soglia coincide con quella del backend', () {
    test('senza numeri lo dice, perché il server rifiuterebbe', () {
      expect(
        v('cavallodivano').suggerimenti.any((s) => s.contains('numero')),
        isTrue,
      );
    });

    test('una password vuota non è né buona né cattiva: non c\'è', () {
      final forza = v('');

      expect(forza.level, PasswordLevel.inesistente);
      expect(forza.suggerimenti, isEmpty);
      expect(forza.accettabile, isFalse);
    });

    test('il punteggio resta sempre fra 0 e 4', () {
      for (final p in ['a', 'password', 'Tr0ub4dor&3xKq', 'x' * 200]) {
        expect(v(p).score, inInclusiveRange(0, 4));
      }
    });
  });

  test(
    'a chi ha già una password ottima non si dà nessun consiglio inutile',
    () {
      final forza = v('lampada corvo 41 tenda viola');

      expect(forza.level, PasswordLevel.ottima);
      expect(forza.suggerimenti, isEmpty);
    },
  );
}
