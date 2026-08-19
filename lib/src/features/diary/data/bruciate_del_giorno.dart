import 'package:flutter/foundation.dart';

/// Da dove arrivano le calorie bruciate di oggi — FASE 1.
enum FonteBruciate {
  /// Scritte a mano nella scheda cibo. 🚨 Vincono su tutto.
  manuale('a mano'),

  /// Misurate dall'orologio e lette da Google Health.
  orologio('dall\'orologio'),

  /// Stimate dalla nostra formula sulle sedute registrate (MET × kg × ore).
  stima('stimate'),

  /// Non ce ne sono.
  nessuna('');

  const FonteBruciate(this.etichetta);

  /// 💡 Si mostra accanto al numero. Senza, chi vede 310 invece di 400 non ha
  /// nessun modo di capire perché — e l'unica spiegazione che gli resta è
  /// «l'app sbaglia».
  final String etichetta;
}

/// Le calorie bruciate del giorno, con la loro provenienza — FASE 1.
///
/// ── 🚨 La catena di precedenza vive QUI, e in nessun altro posto ──────────
///
/// | # | Fonte | Vince su |
/// |---|---|---|
/// | 1 | **Manuale** (scheda cibo) | tutto |
/// | 2 | **Google Health** — calorie **attive** del giorno | la formula |
/// | 3 | La nostra formula sulle sedute | — |
///
/// ⚠️ **Non si sommano fra loro, si sostituiscono.** È il tranello centrale di
/// questa funzione: l'orologio ha **già misurato** l'allenamento che la nostra
/// formula sta stimando. Sommarli darebbe a chi si allena il **doppio** del
/// margine calorico, con un numero che resta plausibile e che nessuno andrebbe
/// a verificare.
///
/// 💡 **E svuotare il campo manuale non azzera**: fa scendere di un gradino, a
/// Health se c'è e alla formula se non c'è. È la differenza fra «non lo so» e
/// «oggi ho bruciato zero», e vale su tutta la catena.
@immutable
class BruciateDelGiorno {
  const BruciateDelGiorno._({required this.kcal, required this.fonte});

  final int kcal;
  final FonteBruciate fonte;

  bool get esistono => kcal > 0;

  /// Risolve la catena.
  ///
  /// [manuale] è il valore dichiarato nella scheda cibo — `null` se non c'è.
  /// [daHealth] sono le calorie **attive** lette da Google Health.
  /// [stimate] è quello che calcola la nostra formula sulle sedute.
  ///
  /// 🚨 **`manuale` è `int?` e non `int`**, e la differenza è tutta lì: `0`
  /// dichiarato («oggi non ho bruciato niente») deve **vincere** su Health,
  /// mentre «non l'ho scritto» deve lasciarlo passare. Con un `int` le due cose
  /// sarebbero indistinguibili, e chi scrive zero si vedrebbe comparire il
  /// numero dell'orologio al posto suo.
  factory BruciateDelGiorno.scegli({
    required int? manuale,
    required int daHealth,
    required int stimate,
  }) {
    if (manuale != null) {
      return BruciateDelGiorno._(kcal: manuale, fonte: FonteBruciate.manuale);
    }

    if (daHealth > 0) {
      return BruciateDelGiorno._(kcal: daHealth, fonte: FonteBruciate.orologio);
    }

    if (stimate > 0) {
      return BruciateDelGiorno._(kcal: stimate, fonte: FonteBruciate.stima);
    }

    return const BruciateDelGiorno._(kcal: 0, fonte: FonteBruciate.nessuna);
  }
}
