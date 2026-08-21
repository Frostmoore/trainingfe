import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../privacy/consensi_controller.dart';
import 'dashboard_controller.dart';

/// A che punto è il consiglio del giorno.
enum StatoConsiglio {
  /// È quello di oggi, appena arrivato.
  fresco,

  /// È l'ultimo che abbiamo, ed è di un altro giorno.
  vecchio,

  /// Non ne abbiamo ancora nessuno, ma sta arrivando.
  inArrivo,

  /// Manca il consenso all'AI: c'è qualcosa da **fare**, non da aspettare.
  serveConsenso,

  /// 🆕 L'assistente non è attivo: niente piano, o gettoni finiti.
  ///
  /// 🚨 Prima questo caso finiva in [inArrivo], cioè in una rotellina che
  /// girava per sempre. ⚠️ «Non ce l'hai» e «sta arrivando» sono due frasi
  /// diverse, e solo la prima dice a una persona cosa può fare.
  senzaAi,

  /// L'interruttore è spento e non c'è niente da mostrare.
  spento,
}

/// Il consiglio da mettere a schermo, qualunque cosa stia succedendo.
class ConsiglioDaMostrare {
  const ConsiglioDaMostrare({required this.stato, this.testo, this.generatoIl});

  final StatoConsiglio stato;
  final String? testo;

  /// Quando è stato generato quello che si sta mostrando.
  ///
  /// 💡 Serve a scrivere «di ieri» invece di un generico «vecchio»: una data
  /// dice a chi legge **quanto** fidarsi di quel testo.
  final DateTime? generatoIl;

  bool get haTesto => testo != null && testo!.isNotEmpty;
}

/// Dove si ricorda l'ultimo consiglio ricevuto.
///
/// ── 🚨 Sul telefono, e non chiedendolo al server ──────────────────────────
///
/// Perché il server **cancella** i consigli dei giorni precedenti: `AiAdvice::pota()`
/// gira a ogni scrittura, e non è una svista da correggere — è una promessa,
/// scritta nel suo stesso commento: *«un consiglio è il testo più intimo che
/// abbiamo sul server»*.
///
/// ⚠️ Chiedere al server «dammi quello di ieri» vorrebbe dire **allungare quella
/// conservazione**, cioè pagare in privacy una comodità di interfaccia. Il
/// telefono ce l'ha già letto, e tenerlo lì non costa niente a nessuno.
///
/// ── 💡 Nelle preferenze e non nell'archivio ───────────────────────────────
///
/// Quindi **fuori dal backup**, di proposito: è una copia di comodo, non un dato
/// da conservare. Chi cambia telefono non ha nessun motivo di ritrovarsi il
/// consiglio di martedì scorso, e metterlo nel backup vorrebbe dire farlo
/// sopravvivere molto più a lungo di quanto sopravvive sul server.
const _chiaveRicordo = 'consiglio.ultimo';

/// Il consiglio del giorno, **che non sparisce mai** — 20/08/2026.
///
/// ── 🚨 Il difetto che chiude ──────────────────────────────────────────────
///
/// La card spariva in **quattro** modi diversi, e tre erano difetti:
///
/// | Quando | Prima | Adesso |
/// |---|---|---|
/// | Sta caricando | ⛔ niente | l'ultimo che abbiamo, o «sto preparando» |
/// | L'AI non risponde | ⛔ niente | l'ultimo che abbiamo |
/// | Il contesto è cambiato e si rigenera | ⛔ niente | l'ultimo che abbiamo |
/// | L'interruttore è spento | niente | niente ✅ |
///
/// 📌 Il committente: *«la card del consiglio del giorno si deve sempre vedere
/// (a meno che io non l'abbia disabilitato), al limite si mostra il consiglio
/// del giorno precedente, se ancora non è pronto quello nuovo»*.
///
/// ⚠️ **La rigenerazione è il caso che si nota di più.** Il server tiene il
/// consiglio in cache su una chiave che comprende il **contesto**: basta
/// segnare un pasto e la chiave cambia, quindi il consiglio si rifà — e per i
/// secondi che ci mette, la card spariva. Chi apre l'app dopo pranzo la vedeva
/// sparire proprio perché aveva usato l'app.
final consiglioDaMostrareProvider =
    FutureProvider.autoDispose<ConsiglioDaMostrare>((ref) async {
      final cache = ref.watch(localCacheProvider);

      ConsiglioDaMostrare? ricordo() {
        final grezzo = cache.getString(_chiaveRicordo);
        if (grezzo == null) return null;

        try {
          final m = jsonDecode(grezzo) as Map<String, dynamic>;
          final testo = m['testo']?.toString();

          if (testo == null || testo.isEmpty) return null;

          return ConsiglioDaMostrare(
            stato: StatoConsiglio.vecchio,
            testo: testo,
            generatoIl: DateTime.tryParse(m['generato_il']?.toString() ?? ''),
          );
        } on Object {
          /*
       * ⚠️ Un ricordo illeggibile si **butta**, non fa cadere la schermata: è
       * una comodità, e il prezzo di perderla è rivedere il consiglio di oggi
       * un istante dopo.
       */
          return null;
        }
      }

      /*
   * 🚨 **L'interruttore si guarda per PRIMO, e con `valueOrNull`.**
   *
   * Spento vuol dire «non voglio vedere questa card»: mostrargli il consiglio
   * di ieri sarebbe insistere dopo un no. ⚠️ Ma se lo stato dei consensi non è
   * ancora arrivato si tira dritto — aspettarlo vorrebbe dire far sparire la
   * card mentre si carica, cioè il difetto che stiamo chiudendo.
   */
      final consensi = ref.watch(consensiProvider).valueOrNull;

      if (consensi != null && !consensi.consiglioAutomatico) {
        return const ConsiglioDaMostrare(stato: StatoConsiglio.spento);
      }

      final adesso = ref.watch(adviceProvider);

      return adesso.when(
        data: (c) {
          /*
           * 🆕 **Niente AI: si dice, non si gira** — 21/08/2026.
           *
           * ⚠️ Prima di [ricordo]: chi non ha l'assistente non deve vedere il
           * consiglio di ieri come se ne stesse arrivando uno nuovo.
           */
          if (c.senzaAi) {
            return const ConsiglioDaMostrare(stato: StatoConsiglio.senzaAi);
          }

          if (c.serveConsenso) {
            return const ConsiglioDaMostrare(
              stato: StatoConsiglio.serveConsenso,
            );
          }

          if (c.haTesto) {
            /*
         * 💡 Si ricorda **appena arriva**, non quando serve: il momento in cui
         * servirà è quello in cui non ce l'abbiamo.
         *
         * ⚠️ Scrittura non attesa di proposito — è una preferenza, e far
         * aspettare il disegno della schermata per un `SharedPreferences`
         * sarebbe sproporzionato.
         */
            cache.setString(
              _chiaveRicordo,
              jsonEncode({
                'testo': c.testo,
                'generato_il': (c.generatoIl ?? DateTime.now())
                    .toIso8601String(),
              }),
            );

            return ConsiglioDaMostrare(
              stato: StatoConsiglio.fresco,
              testo: c.testo,
              generatoIl: c.generatoIl,
            );
          }

          /*
       * 🚨 Risposta vuota **con l'interruttore acceso** vuol dire che il server
       * lo sta rifacendo, o che l'AI è spenta lato server. In entrambi i casi
       * l'ultimo che abbiamo è meglio del niente.
       */
          return ricordo() ??
              const ConsiglioDaMostrare(stato: StatoConsiglio.inArrivo);
        },
        loading: () =>
            ricordo() ??
            const ConsiglioDaMostrare(stato: StatoConsiglio.inArrivo),
        error: (_, _) =>
            ricordo() ??
            const ConsiglioDaMostrare(stato: StatoConsiglio.inArrivo),
      );
    });
