/// La settimana programmata, e come si distribuisce — 3b-I.B, 27/08/2026.
///
/// ══ 📌 COS'E' ═════════════════════════════════════════════════════════════
///
/// Assegni le tue schede ai giorni della settimana, dici quante volte vuoi
/// allenarti, e l'app le dispone allontanando quelle che pesano sugli stessi
/// muscoli.
///
/// ══ ⚖️ PERCHE' SI PUO' FARE, E LA PROGRESSIONE DEI CARICHI NO ═════════════
///
/// 📌 *«legalmente 1 e 3 non si possono fare, serve un medico»*.
///
/// 🚨 **Qui l'app non compone niente.** Prende schede che la persona ha già
/// scelto e le **dispone nel tempo**: è un calendario, non un programma di
/// allenamento. ⛔ Il giorno in cui decidesse *quali esercizi* mettere in un
/// giorno si sarebbe passati dall'altra parte — quella dove serve un
/// professionista.
///
/// ══ ⛔ E NON E' AI ════════════════════════════════════════════════════════
///
/// Non servirebbe a niente, costerebbe un gettone e introdurrebbe una
/// variabilità che qui è un **difetto**: toccare «Distribuisci» due volte con
/// gli stessi ingressi deve dare la stessa settimana. 🚨 Una proposta che cambia
/// da sola è una proposta di cui non ci si fida.
library;

import 'dart:math' as math;

import 'gruppo_muscolare.dart';

/// Quanti giorni ha una settimana. 💡 Sta qui perché è il numero che l'algoritmo
/// usa tre volte, e vederlo scritto `7` in tre posti fa dubitare che sia lo
/// stesso sette.
const giorniDellaSettimana = 7;

/// I pesi muscolari di una scheda, per id.
typedef PesiPerScheda = Map<int, Map<GruppoMuscolare, double>>;

/// Quanto due schede si somigliano, da `0` (niente in comune) a `1` (identiche).
///
/// 💡 È il **coseno** fra i due vettori dei pesi muscolari: guarda le
/// proporzioni e non le quantità, quindi una scheda da sei esercizi e una da
/// dodici sugli stessi muscoli risultano — giustamente — la stessa cosa.
///
/// ⚠️ Una scheda **senza muscoli noti** (esercizi non a catalogo) somiglia a
/// zero a tutto: non è vero, ma è il verso prudente — verrà messa dove capita
/// invece di attirare o respingere le altre per un dato che non abbiamo.
double somiglianza(
  Map<GruppoMuscolare, double> a,
  Map<GruppoMuscolare, double> b,
) {
  if (a.isEmpty || b.isEmpty) return 0;

  var prodotto = 0.0;
  var normaA = 0.0;
  var normaB = 0.0;

  for (final peso in a.values) {
    normaA += peso * peso;
  }

  for (final peso in b.values) {
    normaB += peso * peso;
  }

  for (final voce in a.entries) {
    prodotto += voce.value * (b[voce.key] ?? 0);
  }

  if (normaA == 0 || normaB == 0) return 0;

  return prodotto / (math.sqrt(normaA) * math.sqrt(normaB));
}

/// I giorni in cui allenarsi, distribuiti nella settimana.
///
/// 🚨 **Il più lontani possibile fra loro**: con 3 giorni su 7 viene 2-2-3, non
/// 1-1-5. ⛔ Ammucchiarli sarebbe la cosa peggiore che un distributore possa
/// fare, perché è esattamente il difetto che si sta cercando di evitare.
///
/// 💡 `round(i × 7 / n)` fa il lavoro: 3 giorni → lunedì, mercoledì, sabato.
///
/// ⚠️ Più di sette giorni non esistono: si taglia invece di girare, o si
/// riempirebbe due volte lo stesso giorno senza dirlo.
List<int> giorniScelti(int quanti) {
  final n = quanti.clamp(0, giorniDellaSettimana);

  if (n == 0) return const [];

  return [for (var i = 0; i < n; i++) (i * giorniDellaSettimana / n).round()];
}

/// Dispone le schede sui giorni della settimana.
///
/// Restituisce **sette caselle** (indice 0 = lunedì): l'id della scheda, o
/// `null` per il riposo.
///
/// ── 🚨 LE QUATTRO REGOLE, E NIENT'ALTRO ───────────────────────────────────
///
/// 1. **Prima si usano tutte.** ⛔ Nessuna scheda si ripete finché le altre non
///    sono state messe. 💡 Con tre schede e tre giorni viene A-B-C, non A-B-A —
///    che è quello che usciva alla prima stesura, e che nessuno si aspetta.
/// 2. **Distanza fra schede simili.** Dentro il giro, a ogni passo si sceglie
///    quella che somiglia meno a quella messa **per ultima**.
/// 3. **Giorni distribuiti**, vedi [giorniScelti].
/// 4. **A pari merito vince l'ordine dell'utente.** 💡 Se due disposizioni sono
///    equivalenti si tiene quella che rispetta l'ordine in cui le ha elencate:
///    è l'unico modo di essere **deterministici** senza sembrare arbitrari.
///
/// ⚠️ **La prima scheda è sempre la prima dell'elenco**, non «quella che sta
/// meglio da sola»: partire da una scelta spiegabile rende spiegabile tutto il
/// resto.
///
/// 🚨 **La regola 1 viene prima della 2, e l'ordine conta**: senza, a parità di
/// somiglianza si ripescava sempre la prima dell'elenco e le ultime non
/// entravano mai.
List<int?> distribuisci({
  required List<int> schede,
  required int quantiGiorni,
  required PesiPerScheda pesi,
}) {
  final settimana = List<int?>.filled(giorniDellaSettimana, null);

  if (schede.isEmpty) return settimana;

  final giorni = giorniScelti(quantiGiorni);
  final ordine = <int>[];

  /*
   * ⚠️ **Le schede si ripetono se sono meno dei giorni**, e non si lasciano
   * giorni vuoti: chi ha due schede e si allena quattro volte vuole ABAB, non
   * AB e poi due giorni di riposo che non ha chiesto.
   *
   * 💡 `daUsare` è il **giro in corso**: si svuota man mano, e quando finisce
   * si riparte da capo. È così che la regola 1 diventa una riga invece di un
   * conteggio.
   */
  final daUsare = <int>[];

  for (var i = 0; i < giorni.length; i++) {
    if (daUsare.isEmpty) daUsare.addAll(schede);

    if (i == 0) {
      ordine.add(schede.first);
      daUsare.remove(schede.first);
      continue;
    }

    final precedente = ordine.last;
    int? scelta;
    var minima = double.infinity;

    for (final candidata in daUsare) {
      /*
       * ⛔ **Mai due giorni di fila la stessa scheda**, se ce n'è un'altra.
       * Succede solo a cavallo di due giri: dentro un giro la precedente è già
       * stata tolta da `daUsare`.
       */
      if (candidata == precedente && daUsare.length > 1) continue;

      final quanto = somiglianza(
        pesi[precedente] ?? const {},
        pesi[candidata] ?? const {},
      );

      // 💡 `<` e non `<=`: a pari merito resta la prima incontrata, cioè quella
      // che l'utente ha messo prima. È la regola 4.
      if (quanto < minima) {
        minima = quanto;
        scelta = candidata;
      }
    }

    final messa = scelta ?? daUsare.first;

    ordine.add(messa);
    daUsare.remove(messa);
  }

  for (var i = 0; i < giorni.length; i++) {
    settimana[giorni[i]] = ordine[i];
  }

  return settimana;
}
