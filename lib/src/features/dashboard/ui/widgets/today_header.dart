import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/auth_controller.dart';
import '../../../diary/data/bruciate_del_giorno.dart';
import '../../../diary/data/target_del_giorno.dart';
import '../../../forma/forma_controller.dart';
import '../../../health/dati_salute.dart';
import '../../../health/health_controller.dart';
import '../../../health/recupero_controller.dart';
import '../../../onboarding/branding_controller.dart';
import '../../../onboarding/data/gym_branding.dart';
import '../../../profile/corpo_controller.dart';
import '../../../profile/target_locale_controller.dart';
import '../../../profile/ui/widgets/bottone_profilo.dart';
import '../../data/dashboard_models.dart';
import '../../giorno_scelto.dart';
import '../../gettoni_controller.dart';

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
    /*
     * ⚠️ **Il giorno scelto guida tutta l'intestazione** — 3b-O.1b.2.
     * 🚨 Lasciare i numeri su «oggi» sotto una data di tre giorni fa sarebbe il
     * difetto che le frecce dovevano evitare.
     */
    final giorno = ref.watch(giornoSceltoProvider);

    final palestra = ref.watch(brandingControllerProvider).branding;
    final utente = ref.watch(authControllerProvider).user;
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
    final bruciate = BruciateDelGiorno.scegli(
      manuale: n.bruciateAMano,
      daHealth: ref.watch(kcalAttiveOggiProvider).valueOrNull ?? 0,
      stimate: n.burnedKcal,
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

    final attive = ref.watch(kcalAttiveDelGiornoProvider(giorno)).valueOrNull;
    final hrv = recupero?.parametri[MetricaSalute.hrv];
    final battito = recupero?.parametri[MetricaSalute.battitoARiposo];
    final sonno = recupero?.notte?.durata;

    final peso = ref
        .watch(corpoDelGiornoProvider(giorno))
        .valueOrNull
        ?.weightKg;

    final obiettivo = TargetDelGiorno.scegli(
      dalServer: n.haTarget ? n.targetKcal : null,
      locale: ref
          .watch(targetLocaleProvider)
          .valueOrNull
          ?.target
          ?.kcal
          .toDouble(),
      bruciate: bruciate.kcal,
    );

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
                          /*
                           * ══ 🆕 IL NOME: LA PALESTRA, O LA PERSONA ═══════════
                           *
                           * 📌 3b-O.1a.3, 21/08/2026: *«non mi piace che ci sia
                           * scritto "Training Companion" per i free_users, ci
                           * deve essere il loro nome completo»*.
                           *
                           * ⚠️ Prima questa riga **spariva** senza palestra —
                           * scelta di F3, per non scrivere il nome dell'app al
                           * posto di quello della palestra. 💡 La correzione non
                           * è rimettere il nome dell'app: è mettere **il nome
                           * della persona** dove stava quello della palestra.
                           *
                           * 🚨 E il nome **completo**, non solo il primo: qui è
                           * un'intestazione, non un saluto.
                           */
                          Text(
                            (palestra.name?.isNotEmpty ?? false)
                                ? palestra.name!
                                : (utente?.name ?? 'Training Companion'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          /*
                           * 🆕 **Sotto, solo la data** — 3b-O.1a.4.
                           *
                           * ⚠️ Via il «Ciao tizio»: il nome è già sopra, e
                           * ripeterlo in due righe di seguito è la stessa
                           * informazione detta due volte.
                           */
                          Text(
                            _dataDiOggi(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    /*
                     * 🚨 **Il saldo dei gettoni** — richiesta del committente,
                     * 16/08/2026.
                     *
                     * Sta qui e non in una scheda più in basso perché è un
                     * numero che si guarda **prima** di fare qualcosa, non
                     * dopo: chi sta per fotografare un piatto deve sapere di
                     * averne dieci senza andarli a cercare.
                     *
                     * ⚠️ In coda alla riga e non in una riga sua: sopra 328 px
                     * una riga in più spinge fuori il resto dell'intestazione,
                     * ed è la larghezza su cui questo progetto ha già misurato
                     * due difetti di layout.
                     */
                    const _SaldoGettoni(),

                    /*
                     * 👤 **Il profilo, in alto a destra** — M7.1, 18/08/2026.
                     *
                     * 🚨 Qui non c'è nessuna `AppBar` — l'intestazione **è** la
                     * scheda della palestra — quindi il bottone sta in coda a
                     * questa riga: è comunque l'angolo in alto a destra dello
                     * schermo, che è dove le persone lo cercano.
                     *
                     * ⚠️ **Dopo** il saldo dei gettoni e non prima: il saldo si
                     * guarda ogni giorno, il profilo una volta a settimana, e
                     * l'ordine di lettura va dal più usato al meno usato.
                     */
                    const BottoneProfilo(),
                  ],
                ),

                const SizedBox(height: Gap.md),

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
                    _Valore(
                      valore: n.kcal.round().toString(),
                      etichetta: obiettivo.esiste
                          ? 'di ${obiettivo.kcal!.round()} kcal'
                          : 'kcal',
                    ),

                    _Valore(
                      valore: bruciate.kcal.toString(),
                      etichetta: 'bruciate',
                      icona: Icons.local_fire_department_rounded,
                    ),

                    // 🔥 Le calorie **attive**: quelle vere dell'orologio.
                    if (attive != null)
                      _Valore(
                        valore: attive.toString(),
                        etichetta: 'attive',
                        icona: Icons.bolt_rounded,
                      ),

                    /*
                     * 🚨 **Il peso arriva dal TELEFONO, non dal riepilogo del
                     * server** — difetto del 12/08: dopo S5 `body.weightKg` è
                     * sempre `null`, e questa riga mostrava un trattino per
                     * sempre. ⚠️ Adesso, mancando, **non compare**.
                     */
                    if (peso != null)
                      _Valore(
                        valore: peso.toStringAsFixed(1),
                        etichetta: 'kg',
                        icona: Icons.monitor_weight_outlined,
                      ),

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

                    if (forma?.carica.valore != null)
                      _Valore(
                        valore: forma!.carica.valore!.round().toString(),
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
        ),
      ),
    );
  }

  /// 💡 Senza decimali quando non servono: «48» invece di «48.0».
  static String _numero(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

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
            : const Icon(
                Icons.fitness_center_rounded,
                color: Colors.white,
                size: 22,
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

/// Il saldo dei gettoni nell'intestazione — 16/08/2026.
///
/// ── 💡 Perché non mostra niente mentre carica ─────────────────────────────
///
/// Un numero che compare, sparisce e ricompare a ogni apertura è peggio di un
/// numero che arriva mezzo secondo dopo. E se la chiamata fallisce non si
/// scrive «errore» in mezzo al saluto: il saldo semplicemente non c'è, e
/// l'intestazione resta quella di prima.
///
/// ⚠️ **Non blocca niente.** È informativo: il cancello vero è sul server, che
/// risponde `402` con quanti gettoni servivano. Un client non decide mai i
/// permessi — vale qui come per `ai_enabled`.
class _SaldoGettoni extends ConsumerWidget {
  const _SaldoGettoni();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ref
        .watch(gettoniProvider)
        .maybeWhen(
          orElse: () => const SizedBox.shrink(),
          data: (g) {
            /*
         * 🚨 Il contatore c'è **sempre**: illimitato, pieno o a zero.
         *
         * ⚠️ Nasconderlo a chi non ha gettoni comprati sembrava gentile e non
         * lo era: chi lo cerca e non lo trova pensa che sia rotto. Uno zero
         * almeno si capisce, e dice pure cosa fare.
         *
         * 💡 `null` = illimitata: si disegna un simbolo, mai uno zero.
         */
            final testo = g.illimitata ? '∞' : '${g.disponibili ?? 0}';

            return Tooltip(
              message: g.illimitata
                  ? 'Gettoni AI illimitati'
                  // 💡 «comprati», non «questo mese»: sono i soli che questo numero
                  // conta, e chiamarli come non sono farebbe cercare una ricarica
                  // che non è mancata.
                  : 'Ti restano ${g.disponibili ?? 0} gettoni AI comprati',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimaryContainer.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.toll_outlined,
                      size: 16,
                      // 💡 Sotto il costo di una foto cambia colore: chi ha 6
                      // gettoni non è a zero, ma la prossima foto non la fa — e
                      // scoprirlo dopo aver inquadrato il piatto è la sequenza
                      // peggiore.
                      color: g.quasiFiniti
                          ? theme.colorScheme.error
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      testo,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: g.quasiFiniti
                            ? theme.colorScheme.error
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
