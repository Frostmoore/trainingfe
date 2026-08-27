import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/acquisti/data/listino.dart';

/// Il listino che l'app riceve — 3b-H, 26/08/2026.
///
/// ══ 🚨 COSA DIFENDE ═══════════════════════════════════════════════════════
///
/// ⛔ Prima i prezzi erano **scritti dentro la schermata**: «400 richieste al
/// mese», che non era nessuno dei numeri veri. 💡 Adesso arrivano dal server, e
/// quello che resta in Dart è solo **come si leggono** — che è comunque un
/// posto dove si può mentire senza accorgersene.
void main() {
  Listino da(List<(int, int)> pacchetti, {bool abbonato = false}) =>
      Listino.fromJson({
        'abbonato': abbonato,
        'livello': abbonato ? 'plus' : 'free',
        'abbonamento': {'prezzo_cent': 799, 'chiamate_mensili': 150},
        'pacchetti': [
          for (final (g, p) in pacchetti)
            {'gettoni': g, 'prezzo_cent': p, 'nota': 'x'},
        ],
        'gettoni_disponibili': 42,
      });

  group('📥 quello che arriva dal server', () {
    test('si legge tutto', () {
      final l = da([(100, 250)], abbonato: true);

      expect(l.abbonato, isTrue);
      expect(l.livello, 'plus');
      expect(l.prezzoAbbonamentoCent, 799);
      expect(l.chiamateMensili, 150);
      expect(l.gettoniDisponibili, 42);
      expect(l.pacchetti, hasLength(1));
    });

    /// ⚠️ Una risposta monca non deve far esplodere una modale che sta per
    /// chiedere dei soldi: si mostra quel che c'è.
    test('e una risposta vuota non esplode', () {
      final l = Listino.fromJson(const {});

      expect(l.abbonato, isFalse);
      expect(l.livello, 'free');
      expect(l.pacchetti, isEmpty);
      expect(l.ilPiuConveniente, isNull);
    });
  });

  group('💰 il prezzo per gettone', () {
    test('è il prezzo diviso i gettoni', () {
      final l = da([(100, 250), (500, 1000), (2000, 2990)]);

      expect(l.pacchetti[0].centPerGettone, 2.5);
      expect(l.pacchetti[1].centPerGettone, 2.0);
      expect(l.pacchetti[2].centPerGettone, closeTo(1.495, 0.001));
    });

    /// ⛔ Una divisione per zero darebbe `Infinity`, e `Infinity` stampato in
    /// una modale di pagamento è il genere di cosa che si scopre dal cliente.
    test('e un pacchetto da zero gettoni non fa esplodere la divisione', () {
      expect(da([(0, 250)]).pacchetti.single.centPerGettone, 0);
    });
  });

  group('🏆 il taglio che conviene', () {
    /// 🚨 **Si calcola, non si marca a mano.** Il giorno che si aggiunge un
    /// taglio più grande, una scritta «il più conveniente» messa a mano resta
    /// sul vecchio — e diventa una bugia stampata accanto a un prezzo.
    test('è quello col prezzo per gettone più basso', () {
      final l = da([(100, 250), (500, 1000), (2000, 2990)]);

      expect(l.ilPiuConveniente?.gettoni, 2000);
    });

    /// ⚠️ **E non è «il più grande».** Se un giorno il taglio grosso costasse
    /// di più a gettone, marcarlo lo stesso sarebbe una raccomandazione contro
    /// l'interesse di chi legge.
    test('anche quando non è il più grande', () {
      final l = da([(100, 100), (2000, 9000)]);

      expect(l.ilPiuConveniente?.gettoni, 100);
    });

    test('e senza pacchetti non c\'è', () {
      expect(da([]).ilPiuConveniente, isNull);
    });
  });

  group('🇮🇹 i centesimi in euro', () {
    test('si scrivono con la virgola', () {
      expect(euro(799), contains('7,99'));
      expect(euro(2990), contains('29,90'));
    });

    /// 💡 Anche i tondi tengono i decimali: «10 €» accanto a «2,50 €» in una
    /// colonna di prezzi si legge come un errore di stampa.
    test('e i tondi tengono i decimali', () {
      expect(euro(1000), contains('10,00'));
    });
  });
  group('🧿 cosa la modale NON deve dire', () {
    /// Il sorgente **senza i commenti**.
    ///
    /// ⛔ **Al primo giro questa guardia si e' morsa la coda**: i commenti che
    /// spiegano *perche'* quelle parole non ci sono la facevano fallire.
    ///
    /// 💡 E' anche il verso giusto: quello che non deve arrivare a chi legge e'
    /// il **testo a schermo**, non la ragione scritta accanto — che invece deve
    /// restare, o fra sei mesi qualcuno rimette la frase senza sapere perche'
    /// era stata tolta.
    String senzaCommenti(String percorso) {
      final riga = RegExp(r'^\s*(///|//).*\$', multiLine: true);
      final blocco = RegExp(r'/\*.*?\*/', dotAll: true);

      return File(
        percorso,
      ).readAsStringSync().replaceAll(blocco, '').replaceAll(riga, '');
    }

    final modale = senzaCommenti(
      'lib/src/features/acquisti/ui/modale_acquisti.dart',
    );

    /// ══ 🚨 IL NUMERO DELLE RICHIESTE NON SI SCRIVE ═══════════════════
    ///
    /// 📌 *«togli la scritta "150 richieste al mese" non va detto, perché
    /// l'abbonamento non fa solo quello»*.
    ///
    /// ⛔ **Un numero in cima a un'offerta diventa l'offerta.** Chi legge «150
    /// richieste» compra un contatore, lo confronta con i pacchetti di gettoni e
    /// fa la divisione — invece di guardare cosa si porta a casa.
    ///
    /// ⚠️ È la stessa decisione del 16/08 sulla pillola: la dotazione inclusa
    /// è **uso compreso**, non credito da contare.
    test('quante richieste sono incluse', () {
      expect(
        modale.contains('chiamateMensili'),
        isFalse,
        reason: 'la quota inclusa non si mostra: e uso compreso, non un saldo',
      );
    });

    /// ⛔ 📌 *«togliamo il riferimento al piano alimentare (ce l'abbiamo ma
    /// non voglio spingerlo subito)»*. 💡 La funzione c'è: è una scelta di
    /// vetrina, non una cosa che manca.
    test('e il piano alimentare da PDF', () {
      for (final parola in ['PDF', 'nutrizionista', 'piano alimentare']) {
        expect(
          modale.contains(parola),
          isFalse,
          reason: '«$parola» era stato tolto dalla vetrina di proposito',
        );
      }
    });

    /// 🚨 **Non si promette quello che l'app non sa fare.** La modale diceva
    /// «Disdici quando vuoi» e dall'app non si può disdire: o si aggiunge il
    /// portale di Stripe, o la frase non ci va. ⚠️ Il giorno che il portale
    /// arriva, questo test si toglie **insieme** alla frase che si rimette.
    test('e «disdici quando vuoi», finché non si può davvero', () {
      expect(modale.toLowerCase().contains('disdic'), isFalse);
    });
  });
  group('🔁 l\'abbonamento in corso', () {
    Listino con(Object? attivo) =>
        Listino.fromJson({'abbonato': true, 'abbonamento_attivo': attivo});

    test('si legge scadenza, rinnovo e gestibilita', () {
      final a = con({
        'fino_al': '2026-09-27',
        'rinnova': true,
        'gestibile': true,
      }).inCorso!;

      expect(a.finoAl, DateTime(2026, 9, 27));
      expect(a.rinnova, isTrue);
      expect(a.gestibile, isTrue);
    });

    /// ⛔ Gli abbonamenti delle palestre non scadono e non passano da
    /// Stripe: senza data non si scrive niente, e senza cliente il pulsante
    /// «gestisci» non deve comparire — aprirebbe una pagina vuota.
    test('e un abbonamento che non scade non ha data ne gestione', () {
      final a = con({
        'fino_al': null,
        'rinnova': true,
        'gestibile': false,
      }).inCorso!;

      expect(a.finoAl, isNull);
      expect(a.gestibile, isFalse);
    });

    test('e senza abbonamento in corso non c\'e niente', () {
      expect(con(null).inCorso, isNull);
      expect(Listino.fromJson(const {}).inCorso, isNull);
    });
  });
}
