import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/auth_controller.dart';
import '../../../health/recupero_controller.dart';
import '../../../onboarding/branding_controller.dart';
import '../../../onboarding/data/gym_branding.dart';
import '../../../profile/corpo_controller.dart';
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 🚨 A2 — le icone di sistema sopra il gradiente della palestra.
      //
      // Ora, batteria e segnale li disegna Android, non noi, e di serie li fa
      // scuri. Su una palestra con il colore acceso diventano illeggibili — e
      // non è un caso raro: `primaryContainer` nasce dal colore scelto dal
      // cliente, quindi può essere qualunque cosa.
      //
      // ⚠️ Si decide dalla **luminanza** e non da una preferenza: è l'unico modo
      // che regge sia il tema chiaro sia quello scuro sia la palestra nera.
      value: _stileBarraDiSistema(theme.colorScheme.primaryContainer),
      child: Container(
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

        /*
         * 🚨 **`SafeArea` DENTRO il `Container`, non intorno** — A2.
         *
         * Intorno, il gradiente comincerebbe **sotto** la barra di sistema e
         * dietro l'orologio resterebbe una striscia del colore dello sfondo:
         * sembra un errore di disegno. Qui invece il colore riempie fino in
         * cima e a scendere è solo il **contenuto**.
         *
         * ⚠️ E non un padding fisso: la barra di sistema è alta in modo diverso
         * su ogni telefono, e sui modelli con l'isola è il doppio. Un numero
         * scritto a mano è giusto su un telefono e sbagliato su tutti gli altri.
         *
         * `bottom: false` perché sotto ci pensa lo scorrimento della schermata:
         * riservare spazio anche lì lascerebbe un buco in mezzo alla pagina.
         */
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.lg),
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
                          /*
                           * 🚨 Senza palestra, **la riga non c'è** — F3.
                           *
                           * `palestra.name` è `null` per chi si è iscritto
                           * senza codice. ⚠️ Il ripiego sbagliato sarebbe
                           * scrivere «Training Companion»: al posto del nome
                           * della propria palestra comparirebbe il nome
                           * dell'app, come se ci si fosse iscritti al software.
                           *
                           * 💡 Il saluto qui sotto resta, e da solo basta: dice
                           * chi sei e che giorno è, che è ciò per cui questa
                           * intestazione esiste.
                           */
                          if (palestra.name != null && palestra.name!.isNotEmpty)
                            Text(
                              palestra.name!,
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
                      etichetta: n.haTarget
                          ? 'di ${n.targetKcal!.round()} kcal'
                          : 'kcal',
                    ),
                    _Valore(
                      valore: n.burnedKcal.toString(),
                      etichetta: 'bruciate',
                      icona: Icons.local_fire_department_rounded,
                    ),
                    /*
                     * 🚨 **Il peso arriva dal TELEFONO, non dal riepilogo del
                     * server** — difetto riferito il 12/08/2026: *«nella
                     * top-bar peso ancora me lo mostra come —»*.
                     *
                     * Dopo S5 `DashboardService::corpo()` restituisce **solo**
                     * `target_weight_kg`: il peso vero non sta più sul server
                     * (decisione D9-bis). Ma questa riga continuava a chiederlo
                     * a `riepilogo.body.weightKg`, che è quindi **sempre
                     * `null`** — cioè un trattino per sempre, qualunque cosa si
                     * registrasse.
                     *
                     * ⚠️ È la stessa svista già corretta per il sonno in
                     * `RecoveryCard`, rimasta qui perché il campo nel modello
                     * **esiste ancora** e quindi il codice compilava benissimo.
                     * Un `null` che non arriva mai non fa rumore.
                     */
                    _Valore(
                      valore:
                          ref
                              .watch(corpoOggiProvider)
                              .valueOrNull
                              ?.weightKg
                              ?.toStringAsFixed(1) ??
                          '—',
                      etichetta: 'kg',
                      icona: Icons.monitor_weight_outlined,
                    ),
                    /*
                     * ⚠️ Il sonno arriva dal TELEFONO, non dal riepilogo del
                     * server — S4.3. `riepilogo.sleep` dopo S1 e' sempre
                     * `null`, e lasciarlo qui avrebbe mostrato un trattino per
                     * sempre.
                     */
                    _Valore(
                      valore:
                          ref
                              .watch(recuperoProvider)
                              .valueOrNull
                              ?.notte
                              ?.durata ??
                          '—',
                      etichetta: 'sonno',
                      icona: Icons.bedtime_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _dataDiOggi() =>
      DateFormat('EEEE d MMMM', 'it').format(DateTime.now());

  /// Icone di sistema chiare o scure, decise dal colore che ci sta sotto.
  ///
  /// ⚠️ **`Brightness` qui è quella dello SFONDO, e le icone escono al
  /// contrario.** È il punto in cui ci si sbaglia: `statusBarIconBrightness`
  /// vuole la luminosità *delle icone*, mentre `statusBarBrightness` (iOS) vuole
  /// quella *dello sfondo*. Scriverle uguali fa icone bianche su fondo bianco su
  /// una delle due piattaforme, e la si scopre solo sull'altra.
  static SystemUiOverlayStyle _stileBarraDiSistema(Color sfondo) {
    final chiaro =
        ThemeData.estimateBrightnessForColor(sfondo) == Brightness.light;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: chiaro ? Brightness.dark : Brightness.light,
      statusBarBrightness: chiaro ? Brightness.light : Brightness.dark,
    );
  }
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
        // 💡 Senza palestra resta il cerchio con il simbolo dell'app: un buco
        // in cima alla dashboard la fa sembrare rotta, ed è il motivo per cui
        // questo ripiego esiste. Vedi la nota gemella in `GymHeader`.
        child: (palestra.name?.isNotEmpty ?? false)
            ? Text(
                palestra.name!.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              )
            : const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 22),
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
