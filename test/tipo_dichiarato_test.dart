import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/training/data/catalogo_esercizi.dart';
import 'package:training_companion/src/features/training/data/gruppo_muscolare.dart';
import 'package:training_companion/src/features/training/data/storico_unificato.dart';
import 'package:training_companion/src/features/training/data/tipo_scelto.dart';
import 'package:training_companion/src/features/training/muscoli_allenati.dart';

/// Il tipo dichiarato a mano — 3b-B.20.5, 25/08/2026.
///
/// 📌 *«voglio poterci assegnare anche un tipo di allenamento diverso dalla
/// scheda. Tipo corsa, bicicletta, nuoto, ste cose qui, in modo che possa
/// stimare i muscoli coinvolti e le calorie»*.
///
/// ══ 🚨 E NON CONTRADDICE B.9 ══════════════════════════════════════════════
///
/// Il 24/08: *«I gruppi muscolari NON arrivano dall'orologio»*. Quella regola
/// resta, e l'ultimo gruppo di test è lì per difenderla: il codice che scrive il
/// sensore non colora niente, quello che scrivi tu sì.
void main() {
  VoceStorico voce({String tipo = 'STRENGTH_TRAINING', String? dichiarato}) =>
      VoceStorico(
        sedute: const [],
        dalPolso: [
          AllenamentoDaOrologio(
            id: 1,
            fonte: 'com.huami.watch.hmwatchmanager',
            tipo: tipo,
            iniziatoIl: DateTime(2026, 8, 25, 17),
            finitoIl: DateTime(2026, 8, 25, 18),
            nascosto: false,
            staccato: false,
            tipoScelto: dichiarato,
          ),
        ],
      );

  Map<GruppoMuscolare, double> muscoliDi(VoceStorico v) => intensitaDeiMuscoli(
    voci: [v],
    catalogo: CatalogoEsercizi.vuoto,
  );

  group('🏃 quello che vale', () {
    test('senza dichiarazione vale quello dell\'orologio', () {
      expect(voce().tipoDichiarato, isNull);
      expect(voce().tipo, 'STRENGTH_TRAINING');
    });

    /// 🚨 **La dichiarazione vince**: chi ha detto «era una nuotata» ha corretto
    /// proprio il codice del sensore.
    test('la dichiarazione vince su quella dell\'orologio', () {
      final v = voce(dichiarato: 'SWIMMING');

      expect(v.tipoDichiarato, 'SWIMMING');
      expect(v.tipo, 'SWIMMING');
    });
  });

  group('💪 i muscoli, e solo da chi li ha dichiarati', () {
    /// ⛔ **È la regola di B.9, e vale ancora.** Un `STRENGTH_TRAINING` scritto
    /// dall'orologio non deve colorare niente: era una figura che *sembrava
    /// informata*, ed è stata cancellata apposta.
    test('il codice dell\'orologio da solo non colora niente', () {
      expect(muscoliDi(voce()), isEmpty);
    });

    /// 💡 Ma una dichiarazione non è un'ipotesi: se ha detto «nuoto», i muscoli
    /// del nuoto ci sono.
    test('ma quello che hai dichiarato tu sì', () {
      final muscoli = muscoliDi(voce(dichiarato: 'SWIMMING'));

      expect(muscoli[GruppoMuscolare.spalle], isNotNull);
      expect(muscoli[GruppoMuscolare.schiena], isNotNull);
      expect(
        muscoli[GruppoMuscolare.quadricipiti],
        isNull,
        reason: 'nuotando le gambe non spingono come correndo',
      );
    });

    test('e una corsa colora le gambe, non le spalle', () {
      final muscoli = muscoliDi(voce(dichiarato: 'RUNNING'));

      expect(muscoli[GruppoMuscolare.polpacci], isNotNull);
      expect(muscoli[GruppoMuscolare.spalle], isNull);
    });
  });

  group('📇 la tabella degli sport', () {
    /// 🚨 I codici devono essere quelli di Health Connect, o l'etichetta e
    /// l'icona diventerebbero una seconda lista da tenere allineata.
    test('nessun codice è ripetuto', () {
      final codici = TipoScelto.tutti.map((t) => t.codice).toList();

      expect(codici.toSet().length, codici.length);
    });

    /// ⚠️ MET da intensità moderata: sovrastimare le calorie porta a mangiare di
    /// più credendo di essere in deficit.
    test('i MET stanno in un intervallo plausibile', () {
      for (final t in TipoScelto.tutti) {
        expect(
          t.met,
          inInclusiveRange(2, 12),
          reason: '${t.nome} ha un MET fuori scala',
        );
        expect(t.muscoli, isNotEmpty, reason: '${t.nome} non muove niente');
      }
    });

    /// ⛔ **`null` e non un ripiego.** Cadere su un tipo qualunque vorrebbe dire
    /// rimettere in piedi `MuscoliDelTipo` da una porta di servizio.
    test('un codice che non si può scegliere torna null', () {
      expect(TipoScelto.per('SNOWBOARDING'), isNull);
      expect(TipoScelto.per(null), isNull);
      expect(TipoScelto.per('SWIMMING')?.nome, 'Nuoto');
    });
  });
}
