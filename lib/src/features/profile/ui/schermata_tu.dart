import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../acquisti/ui/modale_acquisti.dart';
import '../../auth/auth_controller.dart';
import '../../onboarding/branding_controller.dart';
import '../../scoperta/ui/scelta_citta.dart';
import '../../training/data/limiti_delle_schede.dart';
import '../colore_accento.dart';
import 'widgets/voce_avatar.dart';

/// Come ti vedi e come vedi l'app — 3b-P.1, 22/08/2026.
///
/// ══ 🚨 NASCE PERCHÉ UNA CARD GRANDE NON FACEVA NIENTE ═════════════════════
///
/// 📌 Il committente: *«Questa non ha senso se non fa nulla. Ci mettiamo che se
/// ci clicchi manda a una pagina per mettere l'avatar, cambiare i colori
/// dell'app e la tua città»*.
///
/// ⚠️ **La card del nome era l'unica cosa grande della pagina, ed era inerte.**
/// 🚨 Non è un'occasione sprecata: è una lezione sbagliata. Chi la tocca e non
/// ottiene niente impara che *in questa pagina le cose grandi non si toccano* —
/// e da lì in poi non prova più, nemmeno dove funzionerebbe.
///
/// ── 💡 Perché queste tre cose insieme ────────────────────────────────────
///
/// Avatar, colore e città erano tre righe **sparse** in mezzo a diciannove, fra
/// la copia di sicurezza e i consensi. ⚠️ Sono l'unica famiglia della pagina che
/// non cambia *cosa fa* l'app ma **come ti si presenta**: messe insieme si
/// capisce che sono una scelta di gusto, e non si confondono con gli
/// interruttori che spostano dei dati.
///
/// ⛔ **Il colore non c'è per chi ha una palestra**, e non è una dimenticanza:
/// i colori sono quelli della palestra, e lasciarli cambiare qui vorrebbe dire
/// un'app che si veste da sola e si sveste al primo riavvio.
class SchermataTu extends ConsumerWidget {
  const SchermataTu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /*
     * ⛔ **Il colore non c'è per chi ha una palestra**, e non è una
     * dimenticanza: le tinte sono quelle della palestra, e lasciarle cambiare
     * qui vorrebbe dire un'app che si sveste al primo riavvio, quando il
     * branding si riallinea.
     *
     * 🚨 **`haPalestra` e non `name`**: `GymBranding.neutral` un nome ce l'ha —
     * vale «Training Companion» — quindi `name?.isNotEmpty` risponde di sì per
     * tutti. È il difetto O.D.2, che in questo progetto si è ripresentato
     * **cinque** volte, e l'ultima ha reso invisibile proprio questo selettore.
     */
    final conPalestra = ref
        .watch(brandingControllerProvider)
        .branding
        .haPalestra;

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Il tuo profilo'),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          const Card(
            child: Column(
              children: [
                // 📷 M7.2 — la foto sta in cima: è la prima cosa che una persona
                // vede di sé.
                VoceAvatar(),
                Divider(height: 1),
                VoceCitta(),
              ],
            ),
          ),

          const SizedBox(height: Gap.md),

          /*
           * 🎨 Il colore d'accento — spostato qui da «Impostazioni» il
           * 22/08/2026.
           *
           * ⚠️ **Ha già una storia**: era invisibile per un errore di
           * condizione (O.D.13, la quinta occorrenza di O.D.2), e c'è un test
           * che legge il sorgente per impedirlo di nuovo
           * (`niente_nome_per_la_palestra_test.dart`). 🚨 Quel test cerca
           * `_ScegliColore` **e ora cerca questa schermata**: se un domani il
           * selettore trasloca ancora, va aggiornato lì.
           */
          if (!conPalestra) const SelettoreColore(),
        ],
      ),
    );
  }
}

/// La tavolozza dei colori d'accento.
///
/// 🚨 **Pubblica e in un file suo** — 22/08/2026. Era `_ScegliColore`, privata
/// dentro `profile_screen.dart`, ed è proprio per questo che è rimasta
/// invisibile per giorni senza che nessuno se ne accorgesse: una cosa privata
/// dentro un file da 545 righe non la trova nessuno, nemmeno un test.
class SelettoreColore extends ConsumerWidget {
  const SelettoreColore({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scelto = ref.watch(accentoSceltoProvider);

    /*
     * 🔒 **Dietro l'abbonamento** — 3b-J.2, 27/08/2026.
     *
     * 📌 *«mettiamo anche la scelta dei colori dell'app dietro al gate
     * dell'abbonamento. Chi non è abbonato ha il teal normale»*.
     *
     * ⛔ **Non si nasconde**: si vede, si capisce cos'è, e toccando si arriva
     * alla modale. È la stessa regola di tutta la fase — *«i tasti per fare
     * quella cosa ci devono essere e si deve capire che sono bloccati»*.
     *
     * ⚠️ Qui basta il flag dell'abbonamento: questa scheda la mostra soltanto
     * chi **non ha una palestra**, e chi ce l'ha non la vede affatto (il colore
     * è l'identità del cliente). Le due condizioni stanno insieme in
     * `puoScegliereIlColore`, che è quella che decide davvero il tema.
     */
    final puo = soloSeAbbonato(
      ref.watch(authControllerProvider).user?.abbonato,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(puo ? Icons.palette_outlined : Icons.lock_outline_rounded),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    "Colore dell'app",
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),

            const SizedBox(height: Gap.xs),

            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                puo
                    ? 'Cambia le tinte di tutta l\'app. Resta su questo '
                          'telefono e finisce nella copia di sicurezza.'
                    : 'Con l\'abbonamento scegli le tinte di tutta l\'app.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: Gap.md),

            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final voce in ColoreAccento.tavolozza.entries)
                  Semantics(
                    // ⚠️ Un cerchio colorato senza etichetta è muto per chi usa
                    // un lettore di schermo: sentirebbe «pulsante», per undici
                    // volte di fila.
                    label: voce.key,
                    selected: scelto == voce.key,
                    button: true,
                    child: GestureDetector(
                      /*
                       * ⛔ **Toccando si apre la modale, non si sceglie.** Un
                       * cerchio che non fa niente si legge come un guasto; uno
                       * che porta all'abbonamento si legge come un limite.
                       */
                      onTap: () => puo
                          ? ref
                                .read(accentoSceltoProvider.notifier)
                                .scegli(voce.key)
                          : ModaleAcquisti.mostra(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: voce.value,
                          shape: BoxShape.circle,
                          border: Border.all(
                            /*
                             * ⚠️ **`puo &&`**: chi non è abbonato vede il teal,
                             * e un segno su un colore diverso direbbe che è
                             * quello attivo. 🚨 La preferenza resta salvata —
                             * chi si riabbona la ritrova — ma finché non vale
                             * non deve nemmeno sembrare che valga.
                             */
                            color: puo && scelto == voce.key
                                ? theme.colorScheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        // 💡 Il segno di spunta oltre al bordo: chi non
                        // distingue bene i colori non vedrebbe quale è
                        // selezionato.
                        child: puo && scelto == voce.key
                            ? const Icon(
                                Icons.check_rounded,
                                size: 20,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
