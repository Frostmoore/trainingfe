import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../health/dati_salute.dart';
import '../health/health_controller.dart';
import '../profile/profile_controller.dart';
import 'indice_di_effetto.dart';

/// Il Training Effect Index degli ultimi sette giorni — 08/09/2026.
///
/// ══ 📌 PERCHE' ARRIVA SOLO ADESSO ═════════════════════════════════════════
///
/// Il calcolo è scritto e provato dal **07/09**, con quattordici test. ⛔ Ma
/// restava scollegato, e per una ragione precisa: *«il TEI non si può alimentare
/// finché non si sa quanto è fitto il battito»*.
///
/// ✅ **L'08/09 la sonda ha risposto**: 1.438 campioni in due giorni, **uno al
/// minuto**. La soglia che ci si era dati era «≤ 10 minuti»: siamo dieci volte
/// sopra.
///
/// ══ 🚨 I TRE INGREDIENTI, E COSA SUCCEDE SE UNO MANCA ═════════════════════
///
/// | Serve | Da dove | Se manca |
/// |---|---|---|
/// | I battiti dei 7 giorni | `letture_salute`, metrica `hr` | ⛔ Niente TEI: è il dato |
/// | Il battito **a riposo** | metrica `resting_hr` | ⛔ Niente TEI — vedi sotto |
/// | L'**età** | il profilo | ⛔ Niente TEI — vedi sotto |
///
/// 🚨 **Il battito a riposo non si sostituisce con una media.** È metà della
/// riserva di Karvonen: è quello che rende il TEI di una persona diverso da
/// quello di un'altra a parità di corsa. ⛔ Metterci un 60 di comodo darebbe un
/// numero che somiglia a una misura e non lo è.
///
/// 🚨 **E nemmeno l'età.** La massima si stima con Tanaka (`208 − 0,7 × età`):
/// senza età non c'è massima, senza massima non c'è riserva, e senza riserva il
/// TEI è un'invenzione. ⚠️ Un'età di ripiego — «diciamo 40» — sposta la massima
/// di dieci battiti, e dieci battiti su una riserva di novanta sono l'11%.
///
/// 💡 Quindi qui si torna `null`, e la scheda dice **cosa manca**: è
/// un'informazione, mentre un numero storto non lo è.
final indiceDiEffettoProvider = FutureProvider.autoDispose<IndiceDiEffetto?>((
  ref,
) async {
  final eta = ref.watch(profileProvider).valueOrNull?.age;

  if (eta == null || eta <= 0) return null;

  final archivio = ref.watch(archivioSaluteProvider);

  /*
   * ⚠️ **Otto giorni e non sette**, di proposito: la finestra del TEI parte
   * dalla mezzanotte di sette giorni fa, e `lettureRecenti` conta da adesso.
   * ⛔ Con sette, i campioni della mattina del settimo giorno resterebbero
   * fuori — e sarebbero proprio quelli del giorno più vecchio che conta.
   */
  final battiti = await archivio.lettureRecenti(
    MetricaSalute.battitoMedio,
    giorni: 8,
  );

  if (battiti.isEmpty) return null;

  /*
   * 🚨 **Il battito a riposo più recente, non la media.** Cambia con la forma e
   * con il periodo: usare quello di un mese fa vorrebbe dire calcolare la
   * riserva di una persona che non esiste più.
   *
   * 💡 `lettureRecenti` torna già dal più recente.
   */
  final riposo = await archivio.lettureRecenti(
    MetricaSalute.battitoARiposo,
    giorni: 30,
  );

  if (riposo.isEmpty) return null;

  return ModelloDiEffetto.calcola(
    campioni: [
      for (final b in battiti)
        BattitoNelTempo(bpm: b.valore, quando: b.misurataIl),
    ],
    aRiposo: riposo.first.valore,
    eta: eta,
  );
});
