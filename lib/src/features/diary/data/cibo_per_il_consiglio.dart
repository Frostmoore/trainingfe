/// Il cibo che viaggia col consiglio del giorno — Parte I, I5.2.
///
/// ══ 🚨 IL DIFETTO CHE CHIUDE ══════════════════════════════════════════════
///
/// Con I2.5 il diario alimentare è passato sul telefono, e
/// `AiController::laSettimanaDelCibo()` è rimasta a leggere `food_entries`.
/// ⛔ Da quel momento il consiglio del giorno diceva che **non avevi mangiato
/// niente** — scritto bene, detto con sicurezza, e falso.
///
/// ⚠️ Non dava nessun errore, ed è esattamente la famiglia di difetti che questo
/// progetto insegue: un modello a cui manca il contesto **non tace**, lo inventa.
///
/// ══ 📌 LE TRE REGOLE TRASPORTATE, NON REINVENTATE ════════════════════════
///
/// 📌 Regola R2 della Parte I. Vengono da `laSettimanaDelCibo()`, e ognuna delle
/// tre esiste per una ragione che si perde facilmente:
///
/// | Regola | Perché |
/// |---|---|
/// | `scritto_alle` è **la scrittura più recente** del pasto | 🚨 Chi aggiunge il pane alla cena alle 21:40 sta ancora cenando: l'ora che conta è l'ultimo gesto |
/// | **Oggi non entra** in `week_food` | ⛔ È già in `totals` e in `meals`: ripeterlo darebbe al modello due versioni della stessa giornata |
/// | La settimana va **dal più recente** | ⚠️ È l'ordine di `week_sleep` e `week_workouts`: due ordini diversi nello stesso contesto fanno sbagliare i confronti |
///
/// ══ ⛔ E I NOMI SONO QUELLI DELLA LISTA BIANCA DEL SERVER ════════════════
///
/// `meals`, `week_food`, `eaten_kcal`… 🚨 Quello che non ha esattamente questi
/// nomi **non parte, e non lo dice a nessuno**: `AiController` scarta in
/// silenzio ciò che non riconosce, ed è giusto che lo faccia — ma vuol dire che
/// un nome sbagliato qui è un campo che sparisce senza un errore.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diario_locale.dart';

/// Quanti giorni indietro. **Sette**, come `AiController::GIORNI_DI_STORIA`.
///
/// ⚠️ Se cambia di là cambia anche qui: due finestre diverse darebbero al
/// modello una settimana di cibo e dieci giorni di bruciate, e i confronti che
/// ne uscirebbero sarebbero plausibili e sbagliati.
const giorniDelCibo = 7;

/// Il cibo pronto per la richiesta del consiglio.
class CiboPerIlConsiglio {
  const CiboPerIlConsiglio({
    required this.pasti,
    required this.settimana,
    required this.totali,
  });

  final List<Map<String, Object>> pasti;
  final List<Map<String, Object>> settimana;

  /// I totali di oggi: `kcal`, `proteine`, `carboidrati`, `grassi`.
  final ({double kcal, double proteine, double carboidrati, double grassi})
  totali;

  /// I nomi sono quelli della lista bianca del server.
  Map<String, Object> get payload => {
    if (pasti.isNotEmpty) 'meals': pasti,
    if (settimana.isNotEmpty) 'week_food': settimana,

    /*
     * 🚨 **I totali si mandano SEMPRE, anche a zero**, e non è una svista.
     *
     * ⛔ `totals` è dentro l'hash della cache: è il campo che fa rigenerare il
     * consiglio quando si registra qualcosa. ⚠️ Ometterlo a zero vorrebbe dire
     * che la prima registrazione della giornata **non cambia l'hash** — e il
     * consiglio delle 9 resterebbe identico dopo colazione.
     *
     * 💡 E il modello distingue comunque «non ho segnato niente» da «ho mangiato
     * zero»: nel primo caso `meals` non c'è.
     */
    'eaten_kcal': totali.kcal,
    'eaten_protein_g': totali.proteine,
    'eaten_carbs_g': totali.carboidrati,
    'eaten_fat_g': totali.grassi,
  };
}

/// `2026-09-03` — la forma che `week_food` usa da 3b-AC.
String _giorno(DateTime g) =>
    '${g.year.toString().padLeft(4, '0')}-'
    '${g.month.toString().padLeft(2, '0')}-'
    '${g.day.toString().padLeft(2, '0')}';

/// `21:30` — l'ora **locale**, che è l'unica che il modello sa leggere.
///
/// ⚠️ In UTC leggerebbe le 19:30 per una cena scritta alle 21:30 a Roma, e il
/// ragionamento sul «è tardi» partirebbe da un'ora sbagliata. 💡 Qui è locale
/// per costruzione: `scrittaIl` esce da SQLite nel fuso del telefono.
String _ora(DateTime q) =>
    '${q.hour.toString().padLeft(2, '0')}:${q.minute.toString().padLeft(2, '0')}';

final ciboPerIlConsiglioProvider =
    FutureProvider.autoDispose<CiboPerIlConsiglio>((ref) async {
      ref.watch(revisioneDiarioProvider);

      final diario = ref.watch(diarioLocaleProvider);

      final adesso = DateTime.now();
      final oggi = DateTime(adesso.year, adesso.month, adesso.day);

      // ── I pasti di oggi ────────────────────────────────────────────────
      final pasti = [
        for (final p in await diario.pastiScrittiDel(oggi))
          <String, Object>{
            'meal': p.pasto,

            /*
             * 💡 **Interi**: il server li tronca comunque a `int`, e un decimale
             * in un prompt è un carattere pagato per una precisione che nessuno
             * usa. ⚠️ `round()` e non `toInt()`: 279,6 kcal sono 280, non 279.
             */
            'kcal': p.kcal.round(),
            'p': p.proteine.round(),
            'c': p.carboidrati.round(),
            'f': p.grassi.round(),
            'scritto_alle': _ora(p.scrittaIl),
          },
      ];

      // ── La settimana, senza oggi ───────────────────────────────────────
      final da = DateTime(oggi.year, oggi.month, oggi.day - giorniDelCibo);

      final perGiorno = await diario.totaliFra(da, oggi);

      final settimana = <Map<String, Object>>[];

      /*
       * 🚨 **Dal più recente**, e si parte da 1: `i = 0` sarebbe oggi.
       *
       * ⛔ Oggi è già in `totals` e in `meals`. Ripeterlo qui darebbe al modello
       * due versioni della stessa giornata — una completa e una da confrontare
       * con le altre — e il confronto «oggi contro la settimana» perderebbe
       * senso perché oggi starebbe da tutt'e due le parti.
       */
      for (var i = 1; i <= giorniDelCibo; i++) {
        final quale = DateTime(oggi.year, oggi.month, oggi.day - i);
        final t = perGiorno[_giorno(quale)];

        // 💡 Un giorno senza voci **non si manda**: uno zero direbbe «a digiuno»
        // a chi ha solo saltato il diario, ed è il difetto che le medie di
        // `SerieDelCibo` evitano per la stessa ragione.
        if (t == null) continue;

        settimana.add({
          'd': _giorno(quale),
          'kcal': t.kcal.round(),
          'p': t.proteine.round(),
          'c': t.carboidrati.round(),
          'f': t.grassi.round(),
        });
      }

      return CiboPerIlConsiglio(
        pasti: pasti,
        settimana: settimana,
        totali: await diario.totaliDel(oggi),
      );
    });
