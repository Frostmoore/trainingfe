/// Di che settimana parla lo Storico — 3b-A.4.1, 24/08/2026.
///
/// ══ 🚨 IL LUNEDÌ, E NEL FUSO DELLA PERSONA ═════════════════════════════════
///
/// 📌 Il committente: *«Va aggiunto, nell'header, un navigatore per settimana e
/// lo storico deve essere ordinato per settimana»*.
///
/// ⚠️ **`DateTime(y, m, d)` costruisce nel fuso del telefono, ma legge
/// `year`/`month`/`day` dall'oggetto che riceve.** Su un `DateTime` in UTC quei
/// campi sono i componenti UTC: una seduta di lunedì alle 00:30 finirebbe nella
/// settimana prima. 🚨 È la stessa trappola di `GiornoLocale`, e qui si
/// vedrebbe sull'allenamento della domenica sera.
///
/// 💡 Il `.toLocal()` sta a monte, in `WorkoutSession.fromJson`: qui non si
/// rimedia, perché rimediare due volte nasconde dove sta la regola.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// La forma che avevano già `_PerSettimana` e adesso anche il navigatore.
///
/// 🚨 **Una funzione sola, e non è pedanteria**: se il raggruppamento e il
/// navigatore calcolassero il lunedì in due modi, basterebbe una differenza di
/// un'ora per far sparire una seduta dalla settimana che la contiene — e la
/// pagina direbbe «nessun allenamento» su una settimana in cui ce n'è uno.
DateTime lunediDi(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

/// Quale settimana si sta guardando: sempre un **lunedì a mezzanotte**.
///
/// ── ⛔ Non si va nel futuro ───────────────────────────────────────────────
///
/// 💡 Stessa scelta di `GiornoScelto`: la freccia in avanti si **spegne** sulla
/// settimana in corso invece di portare a una schermata vuota che sembra un
/// guasto. Un allenamento della settimana prossima non esiste.
class SettimanaScelta extends Notifier<DateTime> {
  @override
  DateTime build() => lunediDi(DateTime.now());

  /// `true` quando si sta guardando la settimana in corso.
  bool get eQuesta => state == lunediDi(DateTime.now());

  void indietro() => state = state.subtract(const Duration(days: 7));

  void avanti() {
    if (eQuesta) return;

    state = state.add(const Duration(days: 7));
  }

  /// 💡 Si torna a questa settimana in un colpo, toccando la data: con le
  /// frecce, da marzo, ci vorrebbero venti tocchi.
  void questa() => state = lunediDi(DateTime.now());

  /// Va alla settimana di una data qualunque.
  ///
  /// 🚨 Serve allo stato vuoto: *«l'ultimo allenamento è del 3 agosto»* con un
  /// pulsante che ci porta. ⛔ Senza, chi si è fermato un mese dovrebbe premere
  /// la freccia indietro finché non ricompare qualcosa — cioè cercare a
  /// tentoni una cosa che l'app sa già dov'è.
  void vaiA(DateTime quando) => state = lunediDi(quando);
}

final settimanaSceltaProvider = NotifierProvider<SettimanaScelta, DateTime>(
  SettimanaScelta.new,
);
