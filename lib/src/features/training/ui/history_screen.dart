import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/aggiornamento.dart';
import '../../../core/ui/foto_locale.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../../core/ui/states.dart';
import '../../health/tipo_allenamento.dart';
import '../../progress/progress_controller.dart';
import '../data/storico_unificato.dart';
import '../session_controller.dart';
import '../settimana_scelta.dart';
import '../storico_unificato_controller.dart';
import '../training_controller.dart';
import 'widgets/barra_settimana.dart';

/// Lo storico degli allenamenti — C10.
///
/// Raggruppato **per settimana** come nell'app storica: la domanda che ci si
/// fa guardandolo è «quante volte mi sono allenato questa settimana», e un
/// elenco piatto di date costringe a contarle a mano.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const Scaffold(
    /*
     * 🆕 **Il navigatore sta anche qui** — 3b-A.4.1.
     *
     * ⚠️ Ci si arriva dalla scheda «Allenamento» del riepilogo di oggi, ed è lo
     * **stesso** storico della sezione Allenamento. Averlo di là e non di qua
     * lo farebbe sembrare una funzione che va e viene a seconda di come ci sei
     * entrato.
     */
    appBar: IntestazioneApp(
      titolo: 'Storico allenamenti',
      altezzaSotto: altezzaBarraSettimana,
      sotto: BarraSettimana(),
    ),
    body: StoricoAllenamenti(),
  );
}

/// Lo storico **senza Scaffold**, per poterlo mettere dentro un'altra schermata.
///
/// ⚠️ Da G6 vive dentro la sezione Allenamento, sotto il selettore
/// Storico/Schede. `HistoryScreen` resta come rotta a sé perché ci si arriva
/// anche dalla scheda «Allenamento» del riepilogo di oggi, dove una schermata
/// propria con il suo titolo è la cosa giusta.
class StoricoAllenamenti extends ConsumerWidget {
  const StoricoAllenamenti({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /*
     * 🆕 FASE 1.10 — non più `sessionsProvider`, ma lo storico **fuso**.
     *
     * 🚨 Perché una corsa registrata dall'orologio è un allenamento, e prima di
     * oggi non compariva da nessuna parte: *«molta gente probabilmente o non
     * userà l'app quando si allena o non userà l'orologio»*.
     *
     * ⚠️ La fusione non è concatenazione: chi si allena con l'app aperta **e**
     * l'orologio al polso registra la stessa ora due volte, e le due
     * registrazioni vanno riconosciute come una. Vedi `StoricoUnificato`.
     */
    final voci = ref.watch(storicoUnificatoProvider);

    return voci.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(
        error: ApiClient.unwrapError(e),
        onRetry: () => ref.invalidate(storicoUnificatoProvider),
      ),
      data: (lista) => RefreshIndicator(
        onRefresh: () => aggiornaTutto(context, ref, () {
          ref.invalidate(sessionsProvider);
          ref.invalidate(allenamentiDalPolsoProvider);
        }),
        child: _LaSettimana(tutte: lista),
      ),
    );
  }
}

/// Gli allenamenti della settimana scelta — 3b-A.4, 24/08/2026.
///
/// ══ 🚨 UNA SETTIMANA ALLA VOLTA, NON TUTTE IN FILA ════════════════════════
///
/// 📌 Il committente: *«Va aggiunto, nell'header, un navigatore per settimana e
/// lo storico deve essere ordinato per settimana»*.
///
/// ⛔ Prima le settimane erano **tutte** in un elenco lungo, ognuna con la sua
/// intestazione. Con un navigatore in cima quel disegno diventa contraddittorio:
/// le frecce direbbero di guardare una settimana e sotto ci sarebbero anche le
/// altre. ⚠️ E la riga «18 – 24 ago · 3 sedute» direbbe la stessa cosa del
/// navigatore, a dieci pixel di distanza.
///
/// 💡 Il **conteggio** però serviva davvero — è la domanda che ci si fa
/// guardando lo storico — e infatti non è sparito: è finito nell'etichetta del
/// navigatore, dove sta insieme all'intervallo che descrive.
class _LaSettimana extends ConsumerWidget {
  const _LaSettimana({required this.tutte});

  /// 🚨 **Tutte**, non solo quelle della settimana: lo stato vuoto deve poter
  /// dire *dov'è* l'ultimo allenamento, e per saperlo gli servono le altre.
  final List<VoceStorico> tutte;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inizio = ref.watch(settimanaSceltaProvider);

    final delle = tutte.where((v) => lunediDi(v.quando) == inizio).toList();

    if (delle.isEmpty) return _SettimanaVuota(tutte: tutte);

    /*
     * ══ 🚨 DUE PER RIGA È UNA DIVISIONE, NON UNA LARGHEZZA — 3b-A.5.1 ══════
     *
     * 📌 Il committente: *«rettangoli verticali (due per riga) con la foto
     * sopra e il dettaglio sotto»*.
     *
     * ⛔ La trappola è già stata pagata due volte in questo progetto: una
     * larghezza fissa dentro un contenitore che manda a capo decide il numero
     * di colonne **per caso**. A 328 px il quarto quadrato andava a capo, e
     * niente se ne lamentava — compilava, passava l'analizzatore, e a schermo
     * ne faceva tre.
     *
     * 💡 `crossAxisCount: 2` è la divisione dichiarata: le celle si adattano
     * alla larghezza, non il contrario.
     *
     * ⚠️ **`mainAxisExtent` e non `childAspectRatio`**: con il rapporto,
     * l'altezza del testo cresce con la larghezza dello schermo — su un
     * telefono stretto la parte sotto la foto si stringe e il titolo va in
     * overflow. Qui la foto è proporzionale e il **testo ha un'altezza fissa**,
     * che è quello che serve perché ci stia sempre.
     */
    return LayoutBuilder(
      builder: (context, vincoli) {
        final larghezzaCella = (vincoli.maxWidth - Gap.md * 2 - Gap.sm) / 2;

        return GridView.builder(
          padding: const EdgeInsets.all(Gap.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: Gap.sm,
            mainAxisSpacing: Gap.sm,
            mainAxisExtent:
                larghezzaCella * _CardAllenamento.rapportoFoto +
                _CardAllenamento.altezzaTestoIn(context),
          ),
          itemCount: delle.length,
          /*
           * 💡 Una card sola, che si adatta. Fino al 20/08 erano due classi e
           * uno `switch`: con i gruppi la distinzione non è più «da dove viene»
           * ma «contiene una seduta o no», e una proprietà non merita due
           * gerarchie.
           */
          itemBuilder: (context, i) => _CardAllenamento(voce: delle[i]),
        );
      },
    );
  }
}

/// Una settimana senza allenamenti — 3b-A.4, 24/08/2026.
///
/// ══ 💡 UNO STATO VUOTO CHE SA DOVE GUARDARE ═══════════════════════════════
///
/// ⚠️ Con un navigatore per settimana le settimane vuote diventano una cosa
/// **normale**: chi si è fermato un mese ne trova quattro di fila. ⛔ Un
/// «Nessun allenamento» e basta lo lascerebbe a premere la freccia indietro
/// finché non ricompare qualcosa — cioè a cercare a tentoni una cosa che l'app
/// sa già dov'è.
///
/// 🚨 E le due frasi sono **diverse**: «non ti sei ancora mai allenato» e «in
/// questa settimana no» sono due situazioni che non si somigliano affatto, e
/// dirle allo stesso modo sarebbe scoraggiante per la prima e inutile per la
/// seconda.
class _SettimanaVuota extends ConsumerWidget {
  const _SettimanaVuota({required this.tutte});

  final List<VoceStorico> tutte;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tutte.isEmpty) {
      return const EmptyState(
        icon: Icons.fitness_center_rounded,
        title: 'Nessun allenamento',
        message:
            'Quando ne registri uno lo ritrovi qui, settimana per settimana.',
      );
    }

    // 🚨 `tutte` arriva già dal più recente al più vecchio: `first` è l'ultimo
    // allenamento fatto. Riordinare qui vorrebbe dire due ordini nello stesso
    // schermo, e non c'è motivo.
    final ultimo = tutte.first;
    final inizio = ref.watch(settimanaSceltaProvider);
    final eFuturo = ultimo.quando.isBefore(inizio);

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        const SizedBox(height: Gap.xl),
        EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'Niente in questa settimana',
          message: eFuturo
              ? 'L\'ultimo allenamento è del '
                    '${DateFormat('d MMMM', 'it').format(ultimo.quando)}.'
              : 'Ci sono allenamenti in altre settimane.',
        ),
        Center(
          child: TextButton.icon(
            onPressed: () =>
                ref.read(settimanaSceltaProvider.notifier).vaiA(ultimo.quando),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('Vai all\'ultimo allenamento'),
          ),
        ),
      ],
    );
  }
}

/// Una riga dello storico — FASE 1-bis.
///
/// ── 🚨 Una card sola per due casi che si somigliano ───────────────────────
///
/// Fino al 20/08 erano due classi: la seduta del player e l'allenamento del
/// polso. Con i gruppi la distinzione non è più «da dove viene» — una riga può
/// contenerli **entrambi, più volte** — ma «contiene una seduta o no», e una
/// proprietà non merita due gerarchie.
class _CardAllenamento extends ConsumerWidget {
  const _CardAllenamento({required this.voce});

  /// Quanto è alta la foto rispetto alla larghezza della cella — 3b-A.5.1.
  ///
  /// 💡 Un po' più larga che alta: una foto di allenamento è quasi sempre in
  /// piedi, e un ritaglio 1:1 le taglierebbe la testa. ⚠️ Più alta di così e i
  /// rettangoli non ci starebbero in due per riga senza scorrere per ognuno.
  static const rapportoFoto = 0.78;

  /// L'altezza della parte sotto la foto, **a carattere normale**.
  ///
  /// 🚨 Non dipende dalla **larghezza**, e questo è il punto: `mainAxisExtent`
  /// la somma alla foto per sapere quanto è alta la cella, e un'altezza che
  /// cambia con lo schermo farebbe sforare il titolo sui telefoni stretti.
  ///
  /// ⛔ **Dipende però dal carattere**, e per una volta il difetto l'ha trovato
  /// il test invece dello schermo: a `textScale 1.3` quattro righe in 96 px non
  /// ci stanno, e il blocco andava in overflow. Chi fatica a leggere il
  /// carattere grande ce l'ha **sempre** acceso — non è un caso limite, è una
  /// persona.
  static const altezzaTesto = 96.0;

  /// L'altezza vera, tenuto conto di quanto è grande il carattere.
  ///
  /// ⚠️ Si scala tutto il blocco e non le singole righe: sono quattro righe
  /// corte, e la loro somma cresce in proporzione. 💡 `TextScaler.scale` invece
  /// di `textScaleFactor` — quest'ultimo è deprecato e su Android 14 non
  /// descrive più la scala non lineare.
  static double altezzaTestoIn(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(altezzaTesto);

  final VoceStorico voce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final seduta = voce.seduta;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _apri(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /*
             * 📷 **La foto larga tutto il rettangolo**, come chiesto.
             *
             * ⚠️ Il menù dei tre punti ci sta **sopra**, in alto a destra: sotto
             * ruberebbe una riga alla parte che deve dire cosa hai fatto, e
             * quella parte ha un'altezza fissa.
             */
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Miniatura(voce: voce),

                  Positioned(
                    top: -4,
                    right: -4,
                    child: DecoratedBox(
                      /*
                       * 🚨 Un velo scuro sotto l'icona: su una foto chiara i
                       * tre punti bianchi sparivano, e il menù diventava una
                       * cosa che c'è solo se la sai.
                       */
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: _Azioni(voce: voce, chiaro: true),
                    ),
                  ),

                  /*
                   * 🚨 **La seduta aperta si vede da lontano.** Prima era un
                   * pulsante «Riprendi» in fondo alla riga; in una griglia
                   * quello spazio non c'è, e una seduta lasciata a metà è
                   * proprio la cosa che non deve passare inosservata.
                   */
                  if (seduta != null && seduta.isOpen)
                    Positioned(
                      left: Gap.xs,
                      bottom: Gap.xs,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tema.colorScheme.primary,
                          borderRadius: BorderRadius.circular(Gap.radiusSm),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.sm,
                            vertical: 2,
                          ),
                          child: Text(
                            'in corso',
                            style: tema.textTheme.labelSmall?.copyWith(
                              color: tema.colorScheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(
              height: altezzaTestoIn(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.sm,
                  Gap.xs,
                  Gap.sm,
                  Gap.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _titolo(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    Text(
                      _riga1(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),

                    /*
                     * 💡 La riga dell'orologio compare **anche** quando il
                     * gruppo ha una seduta: il player sa quali esercizi hai
                     * fatto, l'orologio sa quanto ti è costato.
                     *
                     * ⚠️ Ma nella griglia sta su **una riga sola**: lo spazio è
                     * fisso, e quello che non ci sta si legge aprendo la card.
                     */
                    if (voce.dalPolso.isNotEmpty)
                      _RigaOrologio(voce: voce, righe: 1),

                    if (voce.nomeScheda != null)
                      Row(
                        children: [
                          Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 12,
                            color: tema.colorScheme.primary,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              voce.nomeScheda!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tema.textTheme.labelSmall?.copyWith(
                                color: tema.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 💡 Il titolo viene dalla seduta quando c'è: è il nome che la persona
  /// riconosce. Solo se non c'è si usa il tipo dell'orologio.
  String _titolo() {
    final seduta = voce.seduta;
    if (seduta != null) return seduta.titolo;

    return TipoAllenamento.da(voce.dalPolso.first.tipo).nome;
  }

  String _riga1() {
    final seduta = voce.seduta;

    return [
      DateFormat('EEE d/MM · HH:mm', 'it').format(voce.quando),

      if (seduta != null && seduta.isOpen)
        'in corso'
      else
        /*
         * ⚠️ La durata del **gruppo**, buchi compresi, non quella della singola
         * seduta. Una seduta fermata alle 18:30 e ripresa alle 18:35 è durata
         * dalle 18:00 alle 19:00: è il tempo che ci hai messo, che è la domanda
         * che si fa chi guarda.
         */
        '${voce.durata.inMinutes} min',

      if (_kcal() != null) '${_kcal()} kcal${_fonteKcal()}',
    ].join(' · ');
  }

  /// Le calorie da mostrare, secondo la catena decisa in §5 FASE 1.
  ///
  /// ══ 🚨 Le fonti si SOSTITUISCONO, non si sommano ════════════════════════
  ///
  /// | Ordine | Fonte |
  /// |---|---|
  /// | 1 | La correzione **a mano**, se c'è |
  /// | 2 | L'**orologio**, che ha misurato |
  /// | 3 | La nostra **stima** (MET × kg × ore) |
  ///
  /// ⚠️ Fino al 20/08 la card mostrava la stima **e sotto** il numero misurato:
  /// due numeri per la stessa ora, senza dire quale valesse. 📌 Il committente:
  /// *«devono essere usati i dati dell'orologio assegnandoli all'allenamento
  /// sull'app»*.
  ///
  /// 🚨 **La correzione a mano resta sopra a tutto**: chi ha scritto un numero
  /// l'ha scritto apposta, e un sensore non lo sconfessa.
  /// ⚠️ **Tutto si somma sul gruppo, da entrambe le parti.** Fino al 20/08 i
  /// tratti dell'orologio si sommavano e le sedute no — si prendeva solo la
  /// prima — e chi si fermava a metà si vedeva contare metà allenamento.
  int? _kcal() {
    if (voce.kcalCorrettaAMano) return voce.kcalDalleSedute;

    return voce.kcalDalPolso ?? voce.kcalDalleSedute;
  }

  String _fonteKcal() {
    if (voce.kcalCorrettaAMano) return ' (a mano)';
    if (voce.kcalDalPolso != null) return ' (dall\'orologio)';
    if (voce.kcalDalleSedute != null) {
      return ' (${voce.seduta!.etichettaKcal})';
    }

    return '';
  }

  /// 🚨 **Una seduta conclusa si GUARDA, non si riapre.**
  ///
  /// Toccando una riga dello storico si finiva nel player: una schermata che
  /// tiene lo schermo acceso, fa partire i recuperi e invita a registrare serie
  /// — su un allenamento di tre giorni fa.
  ///
  /// ⚠️ Se la riga è **solo** dell'orologio non c'è niente da aprire: non ha
  /// esercizi, e una schermata di dettaglio vuota è peggio di nessuna schermata.
  void _apri(BuildContext context) {
    final seduta = voce.seduta;
    if (seduta == null) return;

    context.push(
      seduta.isOpen
          ? AppRoutes.player(seduta.id)
          : AppRoutes.riepilogo(seduta.id),
    );
  }
}

/// La foto dell'allenamento, o il suo ripiego — 3b-A.5.2, 24/08/2026.
///
/// ══ 🚨 LA MAGGIOR PARTE DEGLI ALLENAMENTI NON HA UNA FOTO ═════════════════
///
/// ⛔ **E in una griglia questo si vede molto più che in un elenco.** Con la
/// foto larga tutto il rettangolo, la mancanza occupa i due terzi della card:
/// un rettangolo grigio ripetuto otto volte non è uno spazio vuoto, è una
/// pagina che sembra rotta.
///
/// 💡 Quindi il ripiego **dice qualcosa**: l'icona del tipo di allenamento su
/// un fondo tinto. ⚠️ Una corsa e una seduta di pesi non si somigliano più, e
/// la card resta leggibile a colpo d'occhio anche senza scatti.
///
/// ⛔ **Non si usa `RiquadroFotoAssente`**: ha un lato fisso di 52 px, pensato
/// per la miniatura di un `ListTile`. In una cella di griglia diventerebbe
/// un'icona minuscola in mezzo a un campo grigio.
class _Miniatura extends ConsumerWidget {
  const _Miniatura({required this.voce});

  final VoceStorico voce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seduta = voce.seduta;

    // 🚨 La miniatura viene dal TELEFONO — S5.3. `sessione.photos` arrivava dal
    // server (C5) e da S5 non c'e' piu': le foto sono file locali.
    final foto = seduta == null
        ? null
        : ref.watch(fotoSessioneProvider(seduta.id)).valueOrNull;

    final prima = (foto == null || foto.isEmpty) ? null : foto.first;

    if (prima != null) return FotoLocale(file: prima.file);

    return _SenzaFoto(voce: voce);
  }
}

/// Il fondo tinto con l'icona del tipo.
class _SenzaFoto extends StatelessWidget {
  const _SenzaFoto({required this.voce});

  final VoceStorico voce;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    /*
     * 💡 Il tipo viene dall'orologio quando c'è, e per una seduta dell'app si
     * ricade sui pesi: è quello che si fa aprendo il player, e un'icona
     * generica direbbe meno di una probabile.
     */
    final icona = voce.dalPolso.isEmpty
        ? Icons.fitness_center_rounded
        : TipoAllenamento.da(voce.dalPolso.first.tipo).icona;

    return DecoratedBox(
      /*
       * ⚠️ Un gradiente e non una tinta piatta: otto rettangoli dello stesso
       * colore esatto sembrano segnaposto in attesa di caricare. Con una
       * sfumatura leggera sembrano quello che sono — una scelta.
       */
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tema.colorScheme.secondaryContainer,
            tema.colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icona,
          size: 40,
          color: tema.colorScheme.onSecondaryContainer.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

/// La riga che dice cosa ha visto l'orologio.
///
/// 💡 Piccola e grigia di proposito: sotto una seduta del player è un
/// **complemento**, non la notizia.
class _RigaOrologio extends StatelessWidget {
  const _RigaOrologio({required this.voce, this.righe});

  final VoceStorico voce;

  /// Quante righe al massimo — 3b-A.5.
  ///
  /// ⚠️ Nella griglia lo spazio sotto la foto è **fisso**: senza un limite,
  /// «dall'orologio (3 tratti) · 47 min · 5,2 km» andrebbe a capo e spingerebbe
  /// fuori la riga della scheda. 💡 `null` = nessun limite, che è come si
  /// comportava prima e come serve dove lo spazio non è contato.
  final int? righe;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    var minuti = 0;
    for (final a in voce.dalPolso) {
      minuti += a.finitoIl.difference(a.iniziatoIl).inMinutes;
    }

    final distanza = voce.distanzaMetri ?? 0;

    return Row(
      children: [
        Icon(
          Icons.watch_outlined,
          size: 14,
          color: tema.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            [
              /*
               * 💡 Quante sessioni ha visto l'orologio: se sono più di una vuol
               * dire che è stato fermato e ripreso, e dirlo spiega perché i
               * minuti qui non tornano con la durata del gruppo.
               */
              voce.dalPolso.length == 1
                  ? 'dall\'orologio'
                  : 'dall\'orologio (${voce.dalPolso.length} tratti)',
              '$minuti min',
              if (distanza > 0) _distanza(distanza),
            ].join(' · '),
            maxLines: righe,
            overflow: righe == null ? null : TextOverflow.ellipsis,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  /// 💡 Sotto il chilometro si scrivono i metri: «0,2 km» per una camminata in
  /// palestra sarebbe una precisione finta.
  static String _distanza(int metri) => metri < 1000
      ? '$metri m'
      : '${(metri / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// I gesti su una riga.
///
/// 🚨 **Un menu e non tre pulsanti.** Sono azioni che si usano di rado — una
/// correzione, un'assegnazione, uno scollegamento — e tre icone su ogni riga
/// renderebbero lo storico un pannello di comando invece di un elenco.
class _Azioni extends ConsumerWidget {
  const _Azioni({required this.voce, this.chiaro = false});

  final VoceStorico voce;

  /// L'icona sta **sopra una foto** — 3b-A.5.
  ///
  /// 🚨 Su una foto chiara i tre punti del colore normale sparivano: il menù
  /// diventava una cosa che c'è solo se la sai già. Bianchi su un velo scuro si
  /// vedono su qualunque scatto.
  final bool chiaro;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<_Gesto>(
    icon: Icon(Icons.more_vert, color: chiaro ? Colors.white : null),
    tooltip: 'Altro',
    onSelected: (g) => switch (g) {
      _Gesto.correggiKcal => _correggiKcal(context, ref),
      _Gesto.assegnaScheda => _scegliScheda(context, ref),
      _Gesto.stacca => _stacca(context, ref),
    },
    itemBuilder: (context) => [
      if (voce.seduta != null)
        const PopupMenuItem(
          value: _Gesto.correggiKcal,
          child: ListTile(
            leading: Icon(Icons.local_fire_department_outlined),
            title: Text('Correggi le calorie'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (voce.dalPolso.isNotEmpty)
        const PopupMenuItem(
          value: _Gesto.assegnaScheda,
          child: ListTile(
            leading: Icon(Icons.assignment_outlined),
            title: Text('Assegna una scheda'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      /*
           * 🚨 Lo scollegamento compare **solo quando c'è qualcosa da
           * scollegare**: una riga con una sola registrazione non è un gruppo, e
           * offrire di dividerla sarebbe un comando che non fa niente.
           */
      if (voce.dalPolso.isNotEmpty &&
          (voce.sedute.isNotEmpty || voce.dalPolso.length > 1))
        const PopupMenuItem(
          value: _Gesto.stacca,
          child: ListTile(
            leading: Icon(Icons.call_split),
            title: Text('Non è lo stesso allenamento'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
    ],
  );

  /// Correzione manuale delle calorie della seduta.
  ///
  /// ⚠️ Svuotare il campo **rimette la stima**, non azzera: è la differenza fra
  /// «non lo so» e «oggi ho bruciato zero», e il backend la rispetta.
  Future<void> _correggiKcal(BuildContext context, WidgetRef ref) async {
    final sessione = voce.seduta;
    if (sessione == null) return;

    final controller = TextEditingController(
      text: sessione.kcalSource == 'manual'
          ? sessione.kcal?.toString() ?? ''
          : '',
    );

    final valore = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calorie bruciate'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'kcal',
            helperText: voce.kcalDalPolso != null
                // 💡 Se l'orologio ha misurato, la stima non è più il ripiego.
                ? 'Vuoto = usa l\'orologio (${voce.kcalDalPolso})'
                : 'Vuoto = usa la stima (${sessione.kcal ?? 0})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (valore == null) return;

    await ref
        .read(sessionActionsProvider)
        .setKcal(sessione.id, valore.isEmpty ? null : int.tryParse(valore));
  }

  /// «Ok, ho fatto questa scheda» — la richiesta del 19/08.
  ///
  /// ⚠️ **Si può sempre togliere.** Una scelta che non si disfa è una trappola,
  /// e qui è facilissimo toccare la riga sbagliata: le corse di due giorni
  /// diversi si somigliano molto.
  Future<void> _scegliScheda(BuildContext context, WidgetRef ref) async {
    /*
     * 🚨 **Tutte le schede, non solo quelle della chat** — 3b-A.2.
     *
     * ⛔ Leggeva `schedeRicevuteProvider`, cioè l'archivio locale: chi riceve
     * le schede dal trainer **dal server** si sentiva rispondere che non ne
     * aveva nessuna. Era il caso normale, non un caso limite.
     */
    final schede = await ref.read(schedeUniteProvider.future);

    if (!context.mounted) return;

    if (schede.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Non hai ancora nessuna scheda da assegnare. '
            'Quelle che crei o che ricevi dal trainer compaiono qui.',
          ),
        ),
      );

      return;
    }

    // 💡 Si assegna al **primo** allenamento del gruppo: è quello che il
    // raggruppamento considera l'inizio, e la card legge da lì.
    final bersaglio = voce.dalPolso.first;

    final scelta = await showModalBottomSheet<_Scelta>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
              child: Text(
                'Che scheda hai fatto?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final s in schede)
              ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: Text(s.name),
                selected: s.id == bersaglio.schedaAssegnata,
                onTap: () => Navigator.of(context).pop(_Scelta(s.id)),
              ),
            if (bersaglio.schedaAssegnata != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Togli l\'assegnazione'),
                onTap: () => Navigator.of(context).pop(const _Scelta(null)),
              ),
            ],
          ],
        ),
      ),
    );

    if (scelta == null) return;

    await assegnaSchedaAllAllenamento(
      ref,
      allenamentoId: bersaglio.id,
      schedaId: scelta.schedaId,
    );
  }

  /// «Non è lo stesso allenamento» — FASE 1-bis.
  ///
  /// ── 🚨 È la contropartita della regola larga ──────────────────────────────
  ///
  /// Dal 20/08 basta **un istante** di sovrapposizione perché due registrazioni
  /// finiscano nella stessa riga. ⚠️ Senza questo comando un raggruppamento
  /// sbagliato — i pesi finiti alle 18:01 e la corsa cominciata alle 18:00 —
  /// farebbe **sparire** un allenamento vero, e non ci sarebbe modo di riaverlo.
  ///
  /// 💡 Si stacca l'**ultimo** allenamento del polso, che è quello che quasi
  /// sempre è di troppo: il gruppo si forma in avanti nel tempo, e l'intruso è
  /// chi è arrivato per ultimo.
  Future<void> _stacca(BuildContext context, WidgetRef ref) async {
    final bersaglio = voce.dalPolso.last;
    final tipo = TipoAllenamento.da(bersaglio.tipo);

    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Non è lo stesso allenamento?'),
        content: Text(
          '«${tipo.nome}» delle '
          '${DateFormat('HH:mm', 'it').format(bersaglio.iniziatoIl)} '
          'diventa un allenamento a sé, e non si unirà più a nessuno.\n\n'
          'Puoi rimetterlo insieme quando vuoi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Separa'),
          ),
        ],
      ),
    );

    if (conferma != true) return;

    await staccaAllenamento(ref, allenamentoId: bersaglio.id, staccato: true);
  }
}

enum _Gesto { correggiKcal, assegnaScheda, stacca }

/// 💡 Un tipo apposta perché `null` dal bottom sheet vuol dire «ho chiuso senza
/// scegliere», e `_Scelta(null)` vuol dire «togli l'assegnazione». ⚠️ Senza
/// questa distinzione chiudere il foglio cancellerebbe la scheda assegnata.
class _Scelta {
  const _Scelta(this.schedaId);

  final int? schedaId;
}
