import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../settimana_controller.dart';

/// 📅 **La settimana programmata, in testata** — `plan_interfaccia.md` I4,
/// 19/11/2026.
///
/// 📌 Tavola «Allenamento — Schede»: sette caselle da lunedì, piene nei giorni
/// che hanno una scheda, e oggi evidenziato. Toccandola si programma.
///
/// ══ 🚨 È L'INGRESSO DEL 27/08, E NON DEVE SPARIRE ══════════════════════════
///
/// 📌 *«Come faccio a fargli programmare le schede nei giorni?»*. ⛔ L'unico
/// ingresso era nella dashboard, e chi voleva programmare andava in
/// Allenamento, dove non c'era niente. Fino al 19/11 era una card «Programma
/// la settimana» in cima all'elenco delle schede: ora è questa striscia, nello
/// stesso posto, e dice **com'è** la settimana invece di dire solo quanti
/// giorni ha.
///
/// ⚠️ **Le caselle piene, non le lettere delle schede**: la tavola disegnava
/// «A, B, C», ma `settimanaProvider` dà gli id delle schede, e un nome di una
/// lettera non esiste. Inventarlo vorrebbe dire due nomi per la stessa scheda.
class SettimanaInTestata extends ConsumerWidget {
  const SettimanaInTestata({super.key});

  /// L'iniziale di ogni giorno, da lunedì — come `settimanaDelPiano`.
  static const iniziali = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final puo = ref.watch(puoProgrammareProvider);

    // ⚠️ Sempre sette caselle, anche prima che l'archivio risponda: sette
    // vuote si leggono come «niente programmato», che è vero finché non si sa.
    final giorni =
        ref.watch(settimanaProvider).valueOrNull ?? List<int?>.filled(7, null);
    final quanti = giorni.whereType<int>().length;

    // 💡 `weekday` va da 1 (lunedì) a 7: l'indice è uno in meno.
    final oggi = DateTime.now().weekday - 1;

    return InkWell(
      onTap: () => context.push(AppRoutes.settimana),
      borderRadius: BorderRadius.circular(Gap.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'LA TUA SETTIMANA',
                    style: tema.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                /*
                 * 🔒 **Si capisce che è bloccato, e perché** — 3b-I.A: *«i
                 * tasti ci devono essere e si deve capire che sono bloccati
                 * dietro un abbonamento»*.
                 */
                Text(
                  !puo
                      ? 'Serve l\'abbonamento'
                      : quanti == 0
                      ? 'Programma'
                      : '$quanti ${quanti == 1 ? 'giorno' : 'giorni'} · cambia',
                  style: tema.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: puo
                        ? tema.colorScheme.primary
                        : tema.colorScheme.error,
                  ),
                ),
                if (!puo) ...[
                  const SizedBox(width: Gap.xs),
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: tema.colorScheme.error,
                  ),
                ],
              ],
            ),
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: Gap.xs + 2),
                  Expanded(
                    child: _Giorno(
                      iniziale: iniziali[i],
                      pieno: i < giorni.length && giorni[i] != null,
                      oggi: i == oggi,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Giorno extends StatelessWidget {
  const _Giorno({
    required this.iniziale,
    required this.pieno,
    required this.oggi,
  });

  final String iniziale;
  final bool pieno;
  final bool oggi;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colore = tema.colorScheme.primary;

    return Column(
      children: [
        Text(
          iniziale,
          style: tema.textTheme.labelSmall?.copyWith(
            fontWeight: oggi ? FontWeight.w800 : FontWeight.w500,
            color: oggi
                ? tema.colorScheme.onSurface
                : tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Gap.xs),
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: pieno ? colore : tema.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(Gap.radiusSm - 2),
              // 💡 Oggi ha il bordo, pieno o vuoto: «oggi tocca a qualcosa?»
              // si legge senza contare le caselle.
              border: oggi
                  ? Border.all(color: tema.colorScheme.onSurface, width: 2)
                  : null,
            ),
            /*
             * ⛔ **Niente manubrio dentro** — 28/08/2026: su questa schermata il
             * committente contò *«tre manubri identici»* con tre significati
             * diversi. Sette in più sarebbero stati peggio: la casella piena
             * dice già «c'è una scheda».
             */
          ),
        ),
      ],
    );
  }
}
