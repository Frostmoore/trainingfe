import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/crypto/contenuto_messaggio.dart';

/// S7 — cosa viaggia dentro una busta.
///
/// 🎯 **Il canale è già quello della chat, e non cambia niente sul server.**
/// Il corpo di un messaggio è byte opachi: metterci dentro una scheda invece di
/// una frase non richiede nessun endpoint nuovo, nessun caricamento a parte,
/// nessun permesso in più.
void main() {
  Map<String, dynamic> schedaFinta() => {
    'id': 12,
    'title': 'Push — petto, spalle, tricipiti',
    'exercises': [
      {'position': 1, 'sets': 4, 'reps': '8-10', 'exercise': {'name': 'Panca piana'}},
      {'position': 2, 'sets': 3, 'reps': '12', 'exercise': {'name': 'Alzate laterali'}},
    ],
  };

  group('il giro completo', () {
    test('una frase resta una frase', () {
      const originale = ContenutoTesto('Domani panca piana, 4 serie da 8.');

      final tornato = ContenutoMessaggio.daChiaro(originale.perLaBusta());

      expect(tornato, isA<ContenutoTesto>());
      expect((tornato as ContenutoTesto).testo, 'Domani panca piana, 4 serie da 8.');
    });

    test('una scheda arriva dall altra parte per intero', () {
      final originale = ContenutoScheda(schedaFinta());

      final tornata = ContenutoMessaggio.daChiaro(originale.perLaBusta());

      expect(tornata, isA<ContenutoScheda>());

      final scheda = tornata as ContenutoScheda;
      expect(scheda.titolo, 'Push — petto, spalle, tricipiti');
      expect(scheda.numeroEsercizi, 2);
      expect(
        (scheda.scheda['exercises'] as List).first,
        containsPair('reps', '8-10'),
      );
    });

    test('un piano alimentare pure', () {
      const originale = ContenutoPianoAlimentare({
        'title': 'Definizione — 2100 kcal',
        'kcal': 2100,
      });

      final tornato = ContenutoMessaggio.daChiaro(originale.perLaBusta());

      expect(tornato, isA<ContenutoPianoAlimentare>());
      expect((tornato as ContenutoPianoAlimentare).titolo, 'Definizione — 2100 kcal');
    });
  });

  /// ⚠️ I messaggi cifrati **prima di S7** contengono testo nudo, non JSON.
  ///
  /// Senza questo ramo, ogni conversazione precedente a questa versione
  /// mostrerebbe un errore su **ogni riga** — e sembrerebbe che la chat si sia
  /// rotta, non che il formato sia cambiato.
  group('i messaggi scritti prima di S7', () {
    test('il testo nudo si legge lo stesso', () {
      final vecchio = ContenutoMessaggio.daChiaro('Ciao, come e andata?');

      expect(vecchio, isA<ContenutoTesto>());
      expect((vecchio as ContenutoTesto).testo, 'Ciao, come e andata?');
    });

    /// 💡 Il caso cattivo: un messaggio vecchio che **per caso** è JSON valido
    /// ma non ha la forma di un contenuto. «{}» o un numero scritto da soli
    /// devono restare testo, non diventare un contenuto vuoto.
    test('un JSON che non e un contenuto resta testo', () {
      for (final strano in ['[1,2,3]', '42', '"solo una stringa"', 'true']) {
        final letto = ContenutoMessaggio.daChiaro(strano);

        expect(letto, isA<ContenutoTesto>(), reason: 'con «$strano»');
        expect((letto as ContenutoTesto).testo, strano);
      }
    });
  });

  /// 🚨 **Il canale deve continuare a funzionare quando il formato cresce.**
  ///
  /// Il giorno in cui si manderà un tipo nuovo, i telefoni non ancora
  /// aggiornati devono dire «aggiorna l'app» — non rompersi, e soprattutto non
  /// far sparire il resto della conversazione.
  test('un tipo mai visto non fa esplodere niente', () {
    final ignoto = ContenutoMessaggio.daChiaro(
      '{"t":"videochiamata","v":9,"data":{"url":"x"}}',
    );

    expect(ignoto, isA<ContenutoSconosciuto>());
    expect((ignoto as ContenutoSconosciuto).tipo, 'videochiamata');
  });

  test('nemmeno un JSON monco', () {
    for (final rotto in ['{"t":"plan"}', '{"v":1}', '{}']) {
      expect(
        () => ContenutoMessaggio.daChiaro(rotto),
        returnsNormally,
        reason: 'con «$rotto»',
      );
    }
  });
}
