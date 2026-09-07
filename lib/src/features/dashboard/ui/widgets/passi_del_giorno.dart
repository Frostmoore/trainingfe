import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../health/health_controller.dart';
import '../../../health/obiettivo_passi.dart';

/// I passi della giornata, sotto le bruciate — 07/09/2026.
///
/// ⚠️ **`ConsumerWidget` e non un parametro**: il numero arriva da un provider
/// che si aggiorna quando l'orologio manda dati nuovi, e passarlo dall'alto
/// avrebbe voluto dire far ridisegnare **tutta** la card di «Oggi» a ogni
/// sincronizzazione — cioè la più cara che abbiamo.
///
/// 📌 Stava nel Diario fino al 07/09/2026, per una mia lettura sbagliata di
/// *«nella prima card delle calorie»*.
///
/// ══ 📌 DA RIGA A BARRA — 08/09/2026 ═══════════════════════════════════════
///
/// Il committente: *«ok che siano sotto a Bruciate, ma così sono troppo piccoli,
/// quasi invisibili. Mettici una bella barra che li conta a step in base al mio
/// obbiettivo»*.
///
/// ⛔ **Era una riga di testo da 12 punti in grigio secondario**, cioè la stessa
/// gerarchia visiva delle note a piè di card. 🚨 Un dato che si guarda ogni
/// giorno non può avere il peso di una didascalia: si legge come una
/// precisazione di qualcos'altro, e a quel punto tanto vale non esserci.
///
/// 💡 **Le tacche non sono decorazione.** Una barra continua dice *«più o meno a
/// che punto sei»*; dieci tacche dicono **quante ne mancano**, perché una tacca
/// è una quantità nota — un decimo dell'obiettivo — e si contano con gli occhi
/// senza leggere nessun numero.
class PassiDelGiorno extends ConsumerWidget {
  const PassiDelGiorno({required this.giorno, super.key});

  final DateTime giorno;

  /// Quante tacche ha la barra.
  ///
  /// 🚨 **Dieci, sempre, qualunque sia l'obiettivo.** Una tacca ogni mille passi
  /// darebbe tre tacche a chi ne punta 3.000 e venti a chi ne punta 20.000: la
  /// stessa barra vorrebbe dire due cose diverse, e chi cambia obiettivo
  /// vedrebbe cambiare il *significato* del disegno invece che il traguardo.
  ///
  /// 💡 Con dieci, una tacca è **sempre il 10%**, e il sottotitolo dice quanti
  /// passi valgono per lei.
  static const tacche = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passi = ref.watch(passiDelGiornoProvider(giorno)).valueOrNull ?? 0;

    /*
     * 🚨 **Zero vuol dire «non lo sappiamo», non «non hai camminato».** Arriva
     * zero in due casi diversi: finché il permesso `STEPS` non è concesso, e nel
     * frame in cui il provider sta ancora caricando.
     *
     * ⛔ Mostrare «0 passi» — o peggio una barra vuota con un obiettivo accanto,
     * che è un rimprovero — a chi ha camminato tutto il giorno direbbe una cosa
     * falsa con l'aria di un dato misurato.
     */
    if (passi <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final obiettivo = ref.watch(obiettivoPassiProvider);
    final raggiunto = passi >= obiettivo;

    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Gap.radiusSm),
        onTap: () => mostraLaScelta(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.directions_walk_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: Gap.xs),
                  Text('Passi', style: theme.textTheme.labelLarge),
                  const Spacer(),

                  /*
                   * 💡 Il numero grande e l'obiettivo piccolo accanto, come
                   * «0 / 1908 kcal» nella stessa card: due dati della stessa
                   * famiglia si leggono uguali, o sembrano cose diverse.
                   */
                  Text(
                    _conIPunti(passi),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: raggiunto
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    ' / ${_conIPunti(obiettivo)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: Gap.xs),

              _BarraATacche(passi: passi, obiettivo: obiettivo),

              const SizedBox(height: Gap.xs),

              Row(
                children: [
                  if (raggiunto)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  if (raggiunto) const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _sottotitolo(passi: passi, obiettivo: obiettivo),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: raggiunto
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),

                  /*
                   * ⚠️ **L'icona c'è perché la barra si tocca**, e non si
                   * indovina. 🚨 In questa stessa app la card del nome era
                   * grande e inerte, e la lezione scritta in `SchermataTu` è
                   * l'opposto: *«chi la tocca e non ottiene niente impara che in
                   * questa pagina le cose grandi non si toccano»*. Vale anche al
                   * rovescio — una cosa che fa qualcosa deve dirlo.
                   */
                  Icon(
                    Icons.tune_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Cosa c'è scritto sotto la barra.
  ///
  /// 🚨 **Mai «0 passi mancanti»**: a obiettivo raggiunto la frase cambia di
  /// tono, non di numero. ⛔ Un traguardo raggiunto che si annuncia con uno zero
  /// si legge come un fallimento.
  @visibleForTesting
  static String sottotitolo({required int passi, required int obiettivo}) =>
      _sottotitolo(passi: passi, obiettivo: obiettivo);

  static String _sottotitolo({required int passi, required int obiettivo}) {
    if (passi >= obiettivo) {
      final oltre = passi - obiettivo;

      return oltre <= 0
          ? 'Obiettivo raggiunto'
          : 'Obiettivo superato di ${_conIPunti(oltre)}';
    }

    return 'Ne mancano ${_conIPunti(obiettivo - passi)} · '
        'una tacca = ${_conIPunti(obiettivo ~/ tacche)}';
  }

  /// Il cursore per cambiare l'obiettivo.
  ///
  /// 💡 **Si apre dalla barra e non dalle impostazioni**: è lì che uno guarda il
  /// numero, ed è lì che gli viene in mente che è troppo alto o troppo basso.
  static Future<void> mostraLaScelta(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final obiettivo = ref.watch(obiettivoPassiProvider);

          return Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Obiettivo di passi',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  '${_conIPunti(obiettivo)} passi al giorno',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Slider(
                  value: obiettivo.toDouble(),
                  min: ObiettivoPassi.minimo.toDouble(),
                  max: ObiettivoPassi.massimo.toDouble(),
                  /*
                   * 💡 `divisions` fa scattare il cursore di mille in mille:
                   * senza, si finirebbe su 10.437 passi — un obiettivo che
                   * nessuno si è dato e che nessuno ricorda.
                   */
                  divisions:
                      (ObiettivoPassi.massimo - ObiettivoPassi.minimo) ~/
                      ObiettivoPassi.passo,
                  label: _conIPunti(obiettivo),
                  onChanged: (valore) => ref
                      .read(obiettivoPassiProvider.notifier)
                      .scegli(valore.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _conIPunti(ObiettivoPassi.minimo),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      _conIPunti(ObiettivoPassi.massimo),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 💡 `10.482` e non `10482`: a colpo d'occhio le migliaia si contano da sole.
  static String _conIPunti(int n) {
    final testo = n.toString();
    final fuori = StringBuffer();

    for (var i = 0; i < testo.length; i++) {
      if (i > 0 && (testo.length - i) % 3 == 0) fuori.write('.');

      fuori.write(testo[i]);
    }

    return fuori.toString();
  }
}

/// Dieci tacche, e l'ultima attiva si riempie a metà.
///
/// 🚨 **Il riempimento parziale non è un vezzo.** Senza, la barra scatterebbe
/// di dieci punti percentuali per volta e resterebbe ferma per mille passi: chi
/// la guarda dopo una passeggiata la vedrebbe identica, e concluderebbe che i
/// passi non arrivano. ⛔ È esattamente il difetto «non li vedo» del 6 settembre,
/// che di un'ora ne è costata una.
class _BarraATacche extends StatelessWidget {
  const _BarraATacche({required this.passi, required this.obiettivo});

  final int passi;
  final int obiettivo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ⛔ Difesa e non ipotesi: un obiettivo a zero arriverebbe da un backup
    // rotto, e qui varrebbe una divisione per zero dentro il disegno.
    final perTacca = obiettivo <= 0 ? 0.0 : obiettivo / PassiDelGiorno.tacche;

    return Row(
      children: [
        for (var i = 0; i < PassiDelGiorno.tacche; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 10,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: perTacca <= 0
                            ? 0.0
                            : ((passi - i * perTacca) / perTacca).clamp(
                                0.0,
                                1.0,
                              ),
                        child: ColoredBox(color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
