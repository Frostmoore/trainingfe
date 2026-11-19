import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/barra_della_data.dart';
import '../../../../core/ui/testata_scura.dart';
import '../../../acquisti/data/gate_dell_abbonamento.dart';
import '../../../diary/data/bruciate_del_giorno.dart';
import '../../../diary/data/target_del_giorno.dart';
import '../../../forma/carica_controller.dart';
import '../../../forma/ui/pezzi_della_forma.dart';
import '../../../health/health_controller.dart';
import '../../../profile/somma_bruciate.dart';
import '../../../profile/target_locale_controller.dart';
import '../../../training/bruciate_locali.dart';
import '../../data/dashboard_models.dart';
import '../../giorno_scelto.dart';
import '../../saldo_calorico.dart';
import 'plancia_di_oggi.dart';

/// La testata di «Oggi»: la palestra, gli strumenti e la data.
///
/// ══ 🌑 DAL 19/11/2026 È UNA `TestataScura` — `plan_interfaccia.md` I2 ══════
///
/// 📌 Tavola «Oggi — la 5 con la testata della 4»: nella testata scura gli
/// strumenti di [PlanciaDiOggi] — batteria, tachimetro, sonno/HRV/battito,
/// carico — e in fondo la data con le frecce.
///
/// 🚨 **La palestra si vede, e non è decorazione** (ADR-A01): la riga col
/// logo la porta `IntestazioneApp`, che `TestataScura` contiene.
///
/// ══ 🔒 CHI NON È ABBONATO NON VEDE STRUMENTI SPENTI ═════════════════════
///
/// 📌 08/09/2026: *«Dall'header dei non abbonati devono sparire: Sonno, HRV,
/// BPM, Carico, Carica, Prontezza»* — **sparire, non sfumare**. Una plancia di
/// strumenti spenti in cima alla pagina sarebbe il muro che quella regola
/// vieta. A chi non è abbonato restano **kcal** e **bruciate**, i due numeri
/// che erano già suoi; il ponte verso l'abbonamento è il banner del corpo,
/// non un buco qui.
class TodayHeader extends ConsumerWidget {
  const TodayHeader({required this.riepilogo, super.key});

  final DashboardSummary riepilogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /*
     * ⚠️ **Il giorno scelto guida tutta la testata** — 3b-O.1b.2.
     * 🚨 Lasciare i numeri su «oggi» sotto una data di tre giorni fa sarebbe il
     * difetto che le frecce dovevano evitare.
     */
    final giorno = ref.watch(giornoSceltoProvider);
    final controllo = ref.read(giornoSceltoProvider.notifier);

    // 🔒 La porta unica dell'abbonamento: `gate_dell_abbonamento.dart`.
    final abbonato = ref.watch(abbonatoProvider);

    final oggi = DateTime.now();
    final eOggi = giorno == DateTime(oggi.year, oggi.month, oggi.day);

    /*
     * ══ 🆕 LA DATA CON LE FRECCE, IN FONDO — 3b-O.1b.2 ══════════════════════
     *
     * 📌 *«ci deve essere una data con le freccette per passare ai giorni
     * precedenti o successivi, centrata, in fondo all'header»*.
     *
     * ⚠️ **In fondo, anche se la tavola del 19/11 la disegnava in alto**: la
     * regola è scritta e la tavola è un disegno (`plan_interfaccia.md` R1/R2,
     * decisione I2.D10). Si legge **dopo** i numeri, cioè risponde a «di
     * quando sono questi?» nel momento in cui uno se lo chiede. Per questo sta
     * in fondo agli strumenti e non nel posto del navigatore, che è in cima.
     */
    final data = BarraDellaData(
      testo: eOggi
          ? 'Oggi · ${DateFormat('d MMMM', 'it').format(giorno)}'
          : DateFormat('EEEE d MMMM', 'it').format(giorno),
      onPrima: controllo.indietro,
      // ⛔ Spenta su oggi: il diario non si compila in anticipo.
      onDopo: eOggi ? null : controllo.avanti,
      onTesto: eOggi ? null : controllo.oggi,
    );

    if (abbonato) {
      // 🔋 Solo per sapere se aggiungere l'avvertenza della carica: senza
      // carica, un'avvertenza su un numero che non c'è sarebbe rumore.
      final carica = ref.watch(caricaProvider).valueOrNull;

      return TestataScura(
        /*
         * 🚨 **Le avvertenze SOPRA gli strumenti** — D-2s/B. `TestataScura` le
         * mette nel loro posto, che viene prima di [strumenti] per
         * costruzione: non dipende dall'ordine in cui le scrivo qui.
         */
        avvertenza: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AvvertenzaStima(),
            if (carica != null) const AvvertenzaDellaCarica(),
          ],
        ),
        strumenti: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PlanciaDiOggi(),
            const SizedBox(height: Gap.md),
            data,
          ],
        ),
      );
    }

    return TestataScura(
      strumenti: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NumeriLiberi(riepilogo: riepilogo, giorno: giorno),
          const SizedBox(height: Gap.md),
          data,
        ],
      ),
    );
  }
}

/// Le calorie mangiate e le bruciate: i due numeri di chi non è abbonato.
///
/// ⚠️ Sono **gli stessi** che la testata mostrava prima del 19/11, con la
/// stessa catena e le stesse regole: cambia solo dove stanno.
class _NumeriLiberi extends ConsumerWidget {
  const _NumeriLiberi({required this.riepilogo, required this.giorno});

  final DashboardSummary riepilogo;
  final DateTime giorno;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = riepilogo.nutrition;

    /*
     * ══ 🚨 «DEL GIORNO», NON «DI OGGI» — 3b-F.7, 26/08/2026 ═════════════════
     *
     * 📌 *«le calorie di ieri sono sbagliate, mi segna bruciate 333 anzi che
     * 580»*. ⛔ C'era `kcalAttiveOggiProvider` mentre la data guardava il
     * giorno scelto: passata la mezzanotte, l'orologio del giorno mostrato
     * spariva. 💡 Il provider giusto è questo, con dentro il giorno.
     *
     * 🚨 E **la catena, non il numero del server** (19/08 sera): lo stesso
     * numero che usa la card sotto, o se ne vedono due diversi.
     */
    final bruciate = BruciateDelGiorno.scegli(
      manuale: null,
      daHealth: ref.watch(kcalAttiveDelGiornoProvider(giorno)).valueOrNull ?? 0,
      stimate:
          ref.watch(bruciateLocaliDelGiornoProvider(giorno)).valueOrNull ?? 0,
    );

    /*
     * ⚠️ **La stessa formula della card, non una parallela.** `consumoDelGiorno`
     * mappa il TDEE sull'ora del giorno, ed è quella che disegna la barra
     * delle bruciate. Senza un TDEE locale resta zero, e restano le sole
     * attive.
     */
    final stimaLocale = ref.watch(targetLocaleProvider).valueOrNull?.target;

    final quotidiano = stimaLocale == null
        ? 0.0
        : consumoDelGiorno(
            tdee: stimaLocale.tdee,
            giorno: giorno,
            adesso: DateTime.now(),
          );

    /*
     * 🚨 **L'obiettivo comprende le bruciate** — N23.B1. La regola sta in
     * `TargetDelGiorno` e in nessun altro posto: decide anche quando **non**
     * sommare, perché il piano del trainer le ha già dentro.
     */
    final obiettivo = TargetDelGiorno.scegli(
      dalServer: n.haTarget ? n.targetKcal : null,
      locale: stimaLocale?.kcal.toDouble(),
      bruciate: bruciate.kcal,
      sommaLeBruciate: ref.watch(sommaLeBruciateProvider),
      bruciateExtra:
          ref.watch(bruciateExtraDelGiornoProvider(giorno)).valueOrNull ?? 0,
    );

    return Wrap(
      spacing: Gap.md,
      runSpacing: Gap.sm,
      children: [
        // 🍽️ Il coperto, lo stesso simbolo del diario (21/08).
        _Valore(
          valore: n.kcal.round().toString(),
          etichetta: obiettivo.esiste
              ? 'di ${obiettivo.kcal!.round()} kcal'
              : 'kcal',
          icona: Icons.restaurant_rounded,
        ),

        /*
         * 🚨 **Lo stesso numero della card, non un altro** — 08/09/2026: la
         * pillola diceva 0 e la card 63 nella stessa schermata. Una sola
         * grandezza: quanto hai bruciato finora oggi, basale compreso.
         */
        _Valore(
          valore: (quotidiano + bruciate.kcal).round().toString(),
          etichetta: 'bruciate',
          icona: Icons.local_fire_department_rounded,
        ),
      ],
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
    final colore = theme.colorScheme.onSurface;

    /*
     * ⛔ **Niente `Expanded` qui** — difetto del 21/08: dentro un `Wrap`
     * lancia `WrapParentData is not a subtype of FlexParentData` e cade tutta
     * la pagina. L'analizzatore non lo vede. 💡 La larghezza fissa la dichiara
     * il figlio: 88 px tengono «2.540» e «bruciate».
     */
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          if (icona != null) Icon(icona, size: 18, color: colore),
          Text(
            valore,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colore,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            etichetta,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
