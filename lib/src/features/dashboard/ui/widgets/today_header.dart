import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/intestazione_app.dart';
import '../../../diary/data/bruciate_del_giorno.dart';
import '../../../diary/data/target_del_giorno.dart';
import '../../../forma/forma_controller.dart';
import '../../../health/dati_salute.dart';
import '../../../health/health_controller.dart';
import '../../../health/recupero_controller.dart';
import '../../../profile/somma_bruciate.dart';
import '../../../profile/target_locale_controller.dart';
import '../../../training/bruciate_locali.dart';
import '../../data/dashboard_models.dart';
import '../../giorno_scelto.dart';

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
    /*
     * ⚠️ **Il giorno scelto guida tutta l'intestazione** — 3b-O.1b.2.
     * 🚨 Lasciare i numeri su «oggi» sotto una data di tre giorni fa sarebbe il
     * difetto che le frecce dovevano evitare.
     */
    final giorno = ref.watch(giornoSceltoProvider);

    final n = riepilogo.nutrition;

    /*
     * 🚨 **L'obiettivo comprende le bruciate** — N23.B1, 19/08/2026.
     *
     * Era il difetto riferito dal committente: la somma esisteva **solo sul
     * server**, che dopo D9-bis non conosce il peso e restituisce `null`. Qui
     * si vedeva quindi il target senza bruciate, o nessun target affatto.
     *
     * 💡 La regola sta in `TargetDelGiorno` e in nessun altro posto: decide
     * anche quando **non** sommare, perche' se il numero viene dal piano del
     * trainer le bruciate ci sono gia' dentro.
     */
    /*
     * 🚨 **La catena, non il numero del server** — difetto del 19/08 sera.
     *
     * ⚠️ Qui passava `n.burnedKcal`, cioe' la stima della formula: l'intestazione
     * mostrava «0 bruciate» e un obiettivo senza le calorie dell'orologio,
     * mentre la scheda cibo — che la catena ce l'aveva — ne mostrava altre. Due
     * numeri diversi nella stessa app, che e' il modo piu' rapido per far
     * smettere qualcuno di fidarsi di entrambi.
     */
    /*
     * 🚨 Dal telefono, non dal server — FASE 11.5. Vedi la nota gemella in
     * `CaloriesCard`: con `workout_sessions` via, i numeri del server sarebbero
     * diventati zero **senza un errore**.
     */
    /*
     * ══ 🚨 «DEL GIORNO», NON «DI OGGI» — 3b-F.7, 26/08/2026 ═════════════════
     *
     * 📌 *«Adesso le calorie di ieri sono sbagliate, mi segna bruciate 333 anzi
     * che 580, perché??»*.
     *
     * ⛔ Qui c'era `kcalAttiveOggiProvider`, mentre la riga sotto guardava il
     * **giorno scelto**. Due sorgenti della stessa catena che parlavano di due
     * giorni diversi: passata la mezzanotte, l'orologio del giorno mostrato
     * spariva e restava solo la stima locale.
     *
     * 🚨 **E il dato non era cambiato: era cambiato il giorno.** 580 diventavano
     * 333 da soli, senza che nessuno toccasse niente — il tipo di difetto che
     * si scopre solo guardando indietro, cioè quasi mai.
     *
     * 💡 Il provider giusto esisteva già: `kcalAttiveOggiProvider` non è altro
     * che questo con `oggi` dentro.
     */
    final bruciate = BruciateDelGiorno.scegli(
      manuale: null,
      daHealth: ref.watch(kcalAttiveDelGiornoProvider(giorno)).valueOrNull ?? 0,
      stimate:
          ref.watch(bruciateLocaliDelGiornoProvider(giorno)).valueOrNull ?? 0,
    );

    /*
     * 🆕 I dati dei valori nuovi — 3b-O.1b.1.
     *
     * 💡 Tutti `valueOrNull`: l'intestazione **non aspetta nessuno**. ⚠️ Un
     * numero che arriva mezzo secondo dopo è meglio di un'intestazione che
     * lampeggia, e la regola «se manca sparisce» lo gestisce da sola.
     */
    final recupero = ref.watch(recuperoProvider).valueOrNull;
    final forma = ref.watch(formaProvider).valueOrNull;

    final hrv = recupero?.parametri[MetricaSalute.hrv];
    final battito = recupero?.parametri[MetricaSalute.battitoARiposo];
    final sonno = recupero?.notte?.durata;

    final obiettivo = TargetDelGiorno.scegli(
      dalServer: n.haTarget ? n.targetKcal : null,
      locale: ref
          .watch(targetLocaleProvider)
          .valueOrNull
          ?.target
          ?.kcal
          .toDouble(),
      bruciate: bruciate.kcal,
      sommaLeBruciate: ref.watch(sommaLeBruciateProvider),
      bruciateExtra:
          ref.watch(bruciateExtraDelGiornoProvider(giorno)).valueOrNull ?? 0,
    );

    /*
     * ══ 🆕 L'INTESTAZIONE È CONDIVISA — 3b-O.1a.6, 21/08/2026 ═══════════════
     *
     * 📌 Il committente: *«questa parte va su TUTTE le pagine, non solo su
     * Oggi»*. 🚨 Quindi la riga con logo, nome, gettoni e profilo **non vive
     * più qui**: sta in [IntestazioneApp], e questo file tiene solo la parte
     * che è davvero di «Oggi» — i valori della giornata e la data con le
     * frecce.
     *
     * ⚠️ **Non è una pulizia**: erano due copie della stessa riga in attesa di
     * divergere, ed è esattamente com'è nato il difetto di §56.3 n° 2 (lo
     * stesso controllo sbagliato scritto in quattro punti).
     *
     * 💡 Qui l'intestazione sta **dentro il corpo** e non in `Scaffold.appBar`:
     * su «Oggi» è alta, porta i numeri, e **deve scorrere via**. Sulle altre
     * pagine è una barra fissa. È l'unica differenza fra i due usi, e
     * `altezzaSotto` resta a zero proprio perché qui nessuno la misura.
     */
    return IntestazioneApp(
      sotto: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /*
                 * ══ 🆕 I VALORI, SU DUE RIGHE E SENZA TRATTINI — 3b-O.1b.1 ══
                 *
                 * 📌 Il committente: *«ci devono essere anche battiti a riposo e
                 * hrv (se disponibili, altrimenti [...] spariscono proprio).
                 * Inoltre, ci devono essere Carico e Carica e Calorie Attive»*.
                 * E: *«li puoi anche disporre su 2 righe»*.
                 *
                 * 🚨 **«Se manca, sparisce» è una regola diversa da quella di
                 * prima.** Il peso senza dato mostrava `—`: un trattino occupa
                 * lo spazio di un numero e **non dice niente**. Togliendolo, si
                 * capisce da soli che quel dato non c'è ancora.
                 *
                 * ⚠️ E i valori sono **nove** dove prima erano quattro: un `Row`
                 * li avrebbe spinti fuori a 280 px, che è la larghezza su cui
                 * questo progetto ha già misurato due difetti di layout. 💡 Un
                 * `Wrap` va a capo da solo — su due righe, o su tre a carattere
                 * ingrandito, senza che nessun numero debba essere scelto a mano.
                 */
            Wrap(
              spacing: Gap.md,
              runSpacing: Gap.sm,
              children: [
                // 🍽️ 21/08/2026: *«tutti gli elementi dell'header hanno
                // un'icona tranne le calorie target, mettiamone una anche
                // li'»*. 💡 Il coperto, lo stesso simbolo del diario: chi
                // tocca la scheda sotto finisce esattamente li'.
                _Valore(
                  valore: n.kcal.round().toString(),
                  etichetta: obiettivo.esiste
                      ? 'di ${obiettivo.kcal!.round()} kcal'
                      : 'kcal',
                  icona: Icons.restaurant_rounded,
                ),

                _Valore(
                  valore: bruciate.kcal.toString(),
                  etichetta: 'bruciate',
                  icona: Icons.local_fire_department_rounded,
                ),

                /*
                 * ══ ⛔ «ATTIVE» NON C'È PIÙ, ED ERA UN DOPPIONE ═════════════
                 *
                 * 📌 Il committente, 22/08/2026: *«che differenza c'è tra
                 * attive e bruciate?»*.
                 *
                 * 🚨 **Nessuna, quasi sempre — ed è la risposta che rende la
                 * domanda un difetto.** `attive` era la lettura grezza
                 * dell'orologio; `bruciate` è la **catena** che sceglie fra
                 * dichiarazione a mano, orologio e stima. Quando l'orologio ha
                 * misurato qualcosa — cioè quasi sempre — la catena sceglie
                 * proprio lui, e i due numeri sono **identici**. Nella
                 * schermata del 22/08: 547 e 547.
                 *
                 * ⚠️ Due etichette diverse sullo stesso numero non sono
                 * ridondanza innocua: fanno cercare una differenza che non
                 * c'è, e chi non la trova conclude che uno dei due sia
                 * sbagliato.
                 *
                 * 💡 Resta `bruciate`, che è quello che **entra
                 * nell'obiettivo**. Da dove viene lo dice la pasticca nella
                 * scheda del diario, con la sua icona.
                 */

                /*
                     * ⛔ **Il peso non sta piu' qui** — 21/08/2026: *«togliamo
                     * il peso dall'header, e' inutile visto che sotto c'e'
                     * proprio una card apposita»*.
                     *
                     * 💡 E toglierlo fa entrare gli altri **su due righe**, che
                     * e' la disposizione chiesta in 3b-O.1b.1: a nove valori ne
                     * servivano tre.
                     */
                if (sonno != null)
                  _Valore(
                    valore: sonno,
                    etichetta: 'sonno',
                    icona: Icons.bedtime_outlined,
                  ),

                if (hrv != null)
                  _Valore(
                    valore: _numero(hrv.valore),
                    etichetta: 'hrv',
                    icona: Icons.favorite_outline_rounded,
                  ),

                if (battito != null)
                  _Valore(
                    valore: _numero(battito.valore),
                    etichetta: 'bpm',
                    icona: Icons.monitor_heart_outlined,
                  ),

                // 🔋 Carico e carica, dalla FASE 2-sexies.
                if (forma?.stanchezza.valore != null)
                  _Valore(
                    valore: '${(forma!.stanchezza.valore! * 100).round()}%',
                    etichetta: 'carico',
                    icona: Icons.trending_up_rounded,
                  ),

                if (forma?.prontezza.valore != null)
                  _Valore(
                    valore: forma!.prontezza.valore!.round().toString(),
                    etichetta: 'carica',
                    icona: Icons.battery_charging_full_rounded,
                  ),
              ],
            ),

            /*
                 * ══ 🆕 LA DATA CON LE FRECCE, IN FONDO — 3b-O.1b.2 ══════════
                 *
                 * 📌 *«ci deve essere una data con le freccette per passare ai
                 * giorni precedenti o successivi, centrata, in fondo
                 * all'header»*.
                 *
                 * 🚨 **In fondo e non in cima**, ed è la posizione giusta oltre
                 * che quella chiesta: si legge **dopo** i numeri, cioè risponde
                 * alla domanda «di quando sono questi?» nel momento in cui uno
                 * se la fa.
                 */
            const SizedBox(height: Gap.md),
            const _BarraData(),
          ],
        ),
      ),
    );
  }

  /// 💡 Senza decimali quando non servono: «48» invece di «48.0».
  static String _numero(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
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

    /*
     * ══ 🚨 NIENTE `Expanded` QUI, E COSTA CARO SBAGLIARSI ═══════════════
     *
     * ⚠️ **Difetto del 21/08**: passando la fila dei valori da `Row` a `Wrap`
     * questo `Expanded` è rimasto, e `Expanded` funziona **solo** dentro un
     * `Flex` — `Row`, `Column`. Dentro un `Wrap` lancia
     * `WrapParentData is not a subtype of FlexParentData`, e siccome
     * l'intestazione sta in cima **cade tutta la pagina**: il committente ha
     * visto «tutto completamente rotto».
     *
     * 🚨 **L'analizzatore non può vederlo**: `Expanded` è un `Widget` valido
     * ovunque, e il contratto è di *disposizione*, non di tipo. Si scopre solo
     * facendo partire l'app — ed è la ragione per cui una modifica di layout va
     * guardata su un telefono prima di dire che è fatta.
     *
     * 💡 La larghezza fissa sostituisce quello che faceva `Expanded`: dentro un
     * `Wrap` nessuno distribuisce lo spazio, quindi la deve dichiarare il
     * figlio. 72 px tengono «1.850» e «bruciate» senza tagliare, e a 280 px ne
     * entrano tre per riga.
     */
    return SizedBox(
      width: 72,
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
            overflow: TextOverflow.ellipsis,
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

/// La data con le frecce — 3b-O.1b.2.
///
/// ⛔ **La freccia in avanti si spegne su oggi.** Il diario non si compila in
/// anticipo, e una giornata che non è ancora successa non ha calorie, peso né
/// sonno: portarci vorrebbe dire una schermata vuota che sembra un guasto.
///
/// 💡 E toccando la data si torna a oggi in un colpo, senza premere la freccia
/// tante volte quanti sono i giorni indietro.
class _BarraData extends ConsumerWidget {
  const _BarraData();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final giorno = ref.watch(giornoSceltoProvider);
    final controllo = ref.read(giornoSceltoProvider.notifier);

    final oggi = DateTime.now();
    final eOggi = giorno == DateTime(oggi.year, oggi.month, oggi.day);

    final sopra = theme.colorScheme.onPrimaryContainer;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: controllo.indietro,
          icon: Icon(Icons.chevron_left_rounded, color: sopra),
          tooltip: 'Giorno prima',
          visualDensity: VisualDensity.compact,
        ),

        Flexible(
          child: GestureDetector(
            onTap: eOggi ? null : controllo.oggi,
            child: Text(
              eOggi
                  ? 'Oggi · ${DateFormat('d MMMM', 'it').format(giorno)}'
                  : DateFormat('EEEE d MMMM', 'it').format(giorno),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: sopra,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        IconButton(
          // ⛔ Spenta su oggi: `null` disabilita il pulsante, e si **vede**.
          onPressed: eOggi ? null : controllo.avanti,
          icon: Icon(
            Icons.chevron_right_rounded,
            color: eOggi ? sopra.withValues(alpha: 0.3) : sopra,
          ),
          tooltip: 'Giorno dopo',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
