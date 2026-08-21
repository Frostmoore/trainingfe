import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Di che giorno parla la pagina «Oggi» — 3b-O.1b.2, 21/08/2026.
///
/// ══ 🚨 NON È UNA MODIFICA GRAFICA ═════════════════════════════════════════
///
/// 📌 Il committente: *«ci deve essere una data con le freccette per passare ai
/// giorni precedenti o successivi, centrata, in fondo all'header»*.
///
/// ⚠️ **Sembra una riga di interfaccia e tocca tutta la pagina.** Fino a oggi
/// «Oggi» mostrava **solo oggi**: `dashboardProvider`, `corpoOggiProvider`,
/// `kcalAttiveOggiProvider`, il consiglio, carico e carica — ognuno calcolava la
/// data per conto suo con `DateTime.now()`.
///
/// 🚨 Perché le frecce funzionino, **ogni scheda deve chiedere il giorno a
/// questo posto**. Una che continuasse a usare `DateTime.now()` mostrerebbe i
/// numeri di oggi sotto la data di tre giorni fa — e sarebbe **peggio di non
/// avere le frecce**: una schermata che mescola due giorni non si distingue da
/// una che funziona.
///
/// 💡 È la stessa forma che il sonno usa già (`sleepNightProvider`), e da lì
/// viene la fiducia che regga: quel meccanismo sfoglia le notti da settimane.
///
/// ── ⛔ Non si va nel futuro ───────────────────────────────────────────────
///
/// Il diario non si compila in anticipo, e una giornata che non è ancora
/// successa non ha calorie, peso né sonno. ⚠️ La freccia in avanti si **spegne**
/// su oggi invece di portare a una schermata vuota che sembra un guasto.
class GiornoScelto extends Notifier<DateTime> {
  @override
  DateTime build() => _mezzanotte(DateTime.now());

  /// `true` quando si sta guardando oggi — serve a spegnere la freccia avanti.
  bool get eOggi => state == _mezzanotte(DateTime.now());

  void indietro() => state = state.subtract(const Duration(days: 1));

  void avanti() {
    if (eOggi) return;

    state = state.add(const Duration(days: 1));
  }

  /// 💡 Torna a oggi in un colpo: toccando la data si rientra, senza dover
  /// premere la freccia tante volte quanti sono i giorni.
  void oggi() => state = _mezzanotte(DateTime.now());

  static DateTime _mezzanotte(DateTime d) => DateTime(d.year, d.month, d.day);
}

final giornoSceltoProvider = NotifierProvider<GiornoScelto, DateTime>(
  GiornoScelto.new,
);
