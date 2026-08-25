import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/serie_prevista.dart';

/// Le serie riga per riga, e il formato vecchio che si adatta — 3b-D.1.
///
/// 📌 *«ogni serie deve avere Ripetizioni, Peso (o niente o Iso.) e Recupero»* ·
/// *«è fondamentale che funzioni tutto correttamente e che le schede già
/// esistenti ricalchino questa nuova impostazione»*.
///
/// 🚨 **La seconda metà della frase è quella difficile**, ed è tutta qui
/// dentro: le schede del trainer continuano ad arrivare dal server nel formato
/// vecchio, quindi l'adattamento non può essere una migrazione — deve stare nel
/// punto in cui si legge.
void main() {
  group('⏪ una scheda scritta prima di oggi', () {
    /// ⚠️ Quattro serie da dodici a quaranta chili **erano già scritte**: la
    /// scheda lo diceva in un modo solo più povero. Espanderle non inventa
    /// niente.
    test('si apre in righe, una per serie', () {
      final serie = serieDellEsercizio({
        'name': 'Panca piana',
        'sets': 4,
        'reps': '12',
        'rest_sec': 90,
        'target_weight': 40.0,
      });

      expect(serie.length, 4);
      expect(serie.every((s) => s.ripetizioni == 12), isTrue);
      expect(serie.every((s) => s.peso == 40.0), isTrue);
      expect(serie.every((s) => s.recuperoSec == 90), isTrue);
    });

    /// 💡 Le schede che scendono dal server hanno `prescription` già
    /// formattata («3 × 8-12») e non `sets`.
    test('e anche una che arriva dal server con la prescrizione', () {
      final serie = serieDellEsercizio({
        'name': 'Trazioni',
        'prescription': '3 × 8-12',
      });

      expect(serie.length, 3);

      /// 🚨 Il numero **più basso** di un intervallo, come già fa
      /// `Prescrizione`: sovrastimare il lavoro fatto porta a credersi più
      /// avanti di dove si è.
      expect(serie.first.ripetizioni, 8);
    });

    /// ⛔ **Mai zero righe.** Una lista vuota diventerebbe una card muta in
    /// mezzo alla scheda.
    test('e chi ha scritto solo il nome ha comunque una riga', () {
      expect(serieDellEsercizio({'name': 'Qualcosa'}).length, 1);
      expect(serieDellEsercizio({'name': 'Zero', 'sets': 0}).length, 1);
    });
  });

  group('🆕 il formato nuovo', () {
    /// 🚨 **Il nuovo comanda.** Se ci sono tutte e due le cose, il riassunto
    /// vecchio è quello che si è scritto per compatibilità e non va riletto.
    test('vince sul riassunto vecchio, quando ci sono tutti e due', () {
      final serie = serieDellEsercizio({
        'name': 'Squat',
        'serie': [
          {'reps': 12, 'weight': 40.0, 'rest_sec': 90},
          {'reps': 10, 'weight': 45.0, 'rest_sec': 90},
          {'reps': 8, 'weight': 50.0, 'rest_sec': 120},
        ],
        // Il riassunto: dice meno, e infatti va ignorato.
        'sets': 3,
        'reps': '12-8',
        'target_weight': 40.0,
      });

      expect(serie.length, 3);
      expect(serie.map((s) => s.peso).toList(), [40.0, 45.0, 50.0]);
      expect(serie.last.recuperoSec, 120, reason: 'il recupero è della riga');
    });

    /// ⚠️ È **la** cosa che il modello vecchio non sapeva dire.
    test('sa dire tre serie con tre pesi diversi', () {
      final json = esercizioInJson(
        nome: 'Squat',
        carico: CaricoDellEsercizio.peso,
        serie: const [
          SeriePrevista(ripetizioni: 12, peso: 40, recuperoSec: 90),
          SeriePrevista(ripetizioni: 10, peso: 45, recuperoSec: 90),
          SeriePrevista(ripetizioni: 8, peso: 50, recuperoSec: 120),
        ],
      );

      final riletto = serieDellEsercizio(json);

      expect(riletto.map((s) => s.ripetizioni).toList(), [12, 10, 8]);
      expect(riletto.map((s) => s.peso).toList(), [40.0, 45.0, 50.0]);
    });
  });

  group('⏪ e si continua a scrivere anche il riassunto', () {
    /// ⛔ **Senza, un backup ripristinato su una versione precedente dell'app
    /// aprirebbe schede con gli esercizi vuoti** — e il ripristino è proprio la
    /// cosa che deve funzionare quando tutto il resto è andato storto.
    test('perché una app più vecchia deve poterla ancora leggere', () {
      final json = esercizioInJson(
        nome: 'Squat',
        carico: CaricoDellEsercizio.peso,
        serie: const [
          SeriePrevista(ripetizioni: 12, peso: 40, recuperoSec: 90),
          SeriePrevista(ripetizioni: 8, peso: 50, recuperoSec: 120),
        ],
      );

      expect(json['sets'], 2);
      expect(json['reps'], '12-8', reason: 'dal primo all\'ultimo');
      expect(json['rest_sec'], 90, reason: 'il primo dichiarato');
      expect(json['target_weight'], 40.0);
    });

    test('e quando le ripetizioni non cambiano il riassunto è un numero solo', () {
      final json = esercizioInJson(
        nome: 'Curl',
        carico: CaricoDellEsercizio.peso,
        serie: const [
          SeriePrevista(ripetizioni: 12),
          SeriePrevista(ripetizioni: 12),
        ],
      );

      expect(json['reps'], '12');
    });

    /// ⚠️ Un esercizio a corpo libero non ha un «peso previsto» da riassumere:
    /// scriverne uno vorrebbe dire farlo comparire come carico in ogni conto.
    test('⛔ ma senza peso non si scrive un target_weight', () {
      final json = esercizioInJson(
        nome: 'Plank',
        carico: CaricoDellEsercizio.iso,
        serie: const [SeriePrevista(isoSec: 45, recuperoSec: 60)],
      );

      expect(json.containsKey('target_weight'), isFalse);
      expect(json['carico'], 'iso');
      expect(serieDellEsercizio(json).first.isoSec, 45);
    });
  });

  /// 🚨 Serve all'autocompilazione: compilando la prima riga si riempiono le
  /// altre **solo se nessuno le ha ancora toccate**.
  test('🖊️ una riga sa dire se è ancora intatta', () {
    expect(const SeriePrevista().intatta, isTrue);
    expect(const SeriePrevista(ripetizioni: 10).intatta, isFalse);
    expect(const SeriePrevista(recuperoSec: 60).intatta, isFalse);
  });
}
