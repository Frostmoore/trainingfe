import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/auth_controller.dart';
import '../../../onboarding/branding_controller.dart';
import '../../../onboarding/data/gym_branding.dart';
import '../../data/dashboard_models.dart';

/// L'intestazione di «Oggi»: la palestra e i numeri della giornata.
///
/// 🚨 **La palestra si vede, e non è decorazione.** Questa è un'app
/// white-label: l'iscritto la percepisce come l'app della *sua* palestra, non
/// come un prodotto di qualcun altro in cui è entrato con un codice. Il logo in
/// cima è ciò che rende vero quel patto — ed è anche il motivo per cui il tema
/// si ricostruisce sui colori del cliente (ADR-A01).
///
/// I quattro numeri sono quelli che si guardano per primi: senza, la schermata
/// costringe a scorrere fino alla scheda giusta per sapere come sta andando la
/// giornata.
class TodayHeader extends ConsumerWidget {
  const TodayHeader({required this.riepilogo, super.key});

  final DashboardSummary riepilogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palestra = ref.watch(brandingControllerProvider).branding;
    final utente = ref.watch(authControllerProvider).user;
    final n = riepilogo.nutrition;

    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.lg),
      decoration: BoxDecoration(
        // Il colore della palestra, sfumato: pieno sarebbe una fascia colorata
        // che schiaccia tutto il resto, e con un logo acceso diventerebbe
        // illeggibile.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Logo(palestra: palestra),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      palestra.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      // Il saluto con il nome e la data: dice a colpo d'occhio
                      // che si sta guardando **oggi**, che è la domanda a cui
                      // tutto il resto della schermata risponde.
                      utente == null
                          ? _dataDiOggi()
                          : 'Ciao ${utente.name.split(' ').first} · ${_dataDiOggi()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: Gap.md),

          Row(
            children: [
              _Valore(
                valore: n.kcal.round().toString(),
                etichetta: n.haTarget ? 'di ${n.targetKcal!.round()} kcal' : 'kcal',
              ),
              _Valore(
                valore: n.burnedKcal.toString(),
                etichetta: 'bruciate',
                icona: Icons.local_fire_department_rounded,
              ),
              _Valore(
                valore: riepilogo.body.weightKg == null
                    ? '—'
                    : riepilogo.body.weightKg!.toStringAsFixed(1),
                etichetta: 'kg',
                icona: Icons.monitor_weight_outlined,
              ),
              _Valore(
                valore: riepilogo.sleep?.durata ?? '—',
                etichetta: 'sonno',
                icona: Icons.bedtime_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _dataDiOggi() =>
      DateFormat('EEEE d MMMM', 'it').format(DateTime.now());
}

class _Logo extends StatelessWidget {
  const _Logo({required this.palestra});

  final GymBranding palestra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ⚠️ Il logo può non esserci: molte palestre non lo caricano. L'iniziale su
    // fondo colorato è il ripiego, ed è lo stesso disegno della schermata di
    // accesso — cambiarlo qui farebbe sembrare due app diverse.
    if (palestra.logoUrl == null || palestra.logoUrl!.isEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: palestra.primary,
        child: Text(
          palestra.name.isEmpty ? '?' : palestra.name.characters.first.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: theme.colorScheme.surface,
      backgroundImage: NetworkImage(palestra.logoUrl!),
    );
  }
}

class _Valore extends StatelessWidget {
  const _Valore({required this.valore, required this.etichetta, this.icona});

  final String valore;
  final String etichetta;
  final IconData? icona;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colore = theme.colorScheme.onPrimaryContainer;

    return Expanded(
      child: Column(
        children: [
          if (icona != null) Icon(icona, size: 16, color: colore),
          Text(
            valore,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colore,
            ),
            maxLines: 1,
          ),
          Text(
            etichetta,
            style: theme.textTheme.labelSmall?.copyWith(color: colore),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
