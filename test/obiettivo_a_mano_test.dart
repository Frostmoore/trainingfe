import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_companion/src/core/ui/avvertenza_nutrizionale.dart';
import 'package:training_companion/src/features/profile/data/target_scelto.dart';

/// L'obiettivo scelto a mano, e l'avvertenza — N17, N18.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('il valore scelto a mano', () {
    test('di serie non c\'è: vale la stima', () async {
      expect(await TargetScelto.leggi(), isNull);
    });

    test('il giro completo: salva, rileggi', () async {
      await const TargetScelto(
        kcal: 1800,
        proteineG: 140,
        carboidratiG: 160,
        grassiG: 60,
      ).salva();

      final riletto = await TargetScelto.leggi();

      expect(riletto?.kcal, 1800);
      expect(riletto?.macro.proteineG, 140);
      expect(riletto?.macro.carboidratiG, 160);
      expect(riletto?.macro.grassiG, 60);
    });

    test('🚨 «torna alla stima» lo toglie davvero', () async {
      /*
       * ⚠️ Senza, chi ha provato a cambiare un numero resterebbe legato alla
       * propria scelta per sempre, o dovrebbe ricopiare a mano i valori
       * calcolati — che è il modo per sbagliarli.
       */
      await const TargetScelto(
        kcal: 1500,
        proteineG: 100,
        carboidratiG: 120,
        grassiG: 50,
      ).salva();

      expect(await TargetScelto.leggi(), isNotNull);

      await TargetScelto.dimentica();

      expect(await TargetScelto.leggi(), isNull);
    });

    test('⚠️ una riga malformata vale come «non c\'è»', () async {
      /*
       * 💡 Sono preferenze locali, e una versione futura potrebbe scriverne una
       * forma diversa. Tornare alla stima è sempre corretto; lanciare qui
       * bloccherebbe la schermata principale su un dato accessorio.
       */
      for (final rotta in [
        <String>[],
        ['1800'],
        ['1800', '140', '160'],
        ['1800', 'centoquaranta', '160', '60'],
        ['1800', '-5', '160', '60'],
      ]) {
        SharedPreferences.setMockInitialValues({'target_scelto_a_mano': rotta});

        expect(await TargetScelto.leggi(), isNull, reason: '$rotta è passata');
      }
    });

    test('🚨 sopravvive a un ricalcolo — N18.5', () async {
      /*
       * Chi ha messo un numero a mano non deve ritrovarselo sovrascritto perché
       * ha aggiornato il peso o ha cambiato «dimagrire» in «mantenere».
       *
       * ⚠️ Un valore che si azzera da solo è **peggio** di un valore che non si
       * può cambiare: il secondo è un limite, il primo è un tradimento.
       */
      await const TargetScelto(
        kcal: 2400,
        proteineG: 180,
        carboidratiG: 240,
        grassiG: 80,
      ).salva();

      // Passano cento ricalcoli: nessuno tocca la scelta.
      for (var i = 0; i < 100; i++) {
        expect((await TargetScelto.leggi())?.kcal, 2400);
      }
    });

    test('zero è un valore legittimo, non un errore', () async {
      // 💡 Chi azzera un macro sta dicendo qualcosa (una dieta chetogenica
      // spinge i carboidrati vicino allo zero). Rifiutarlo sarebbe un giudizio.
      await const TargetScelto(
        kcal: 1900,
        proteineG: 160,
        carboidratiG: 0,
        grassiG: 140,
      ).salva();

      expect((await TargetScelto.leggi())?.macro.carboidratiG, 0);
    });
  });

  group('l\'avvertenza', () {
    test('🚨 dice tutte e tre le cose', () {
      /*
       * 1. cos'è — una stima da formule generiche
       * 2. cosa non è — un consiglio medico
       * 3. a chi rivolgersi — o l'avviso lascia la persona dov'era
       */
      final testo = AvvertenzaNutrizionale.testoPerEsteso.toLowerCase();

      expect(testo, contains('stima'));
      expect(testo, contains('formule generiche'));
      expect(testo, contains('non è un consiglio medico'));
      expect(testo, contains('nutrizionista'));
      expect(testo, contains('dietista'));
      expect(testo, contains('medico'));
    });

    test('⚠️ anche la forma corta non ammorbidisce', () {
      // È la lunghezza a cambiare, non il contenuto: una versione breve che
      // omette «non è un consiglio medico» sarebbe la versione che conta,
      // perché è quella che si legge davvero.
      final breve = AvvertenzaNutrizionale.testoBreve.toLowerCase();

      expect(breve, contains('stima'));
      expect(breve, contains('non è un consiglio medico'));
    });
  });
}
