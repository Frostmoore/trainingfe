import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/storage/archivio_salute.dart';
import '../privacy/consensi_controller.dart';
import 'ponte_salute.dart';

/// L'archivio locale, uno solo per tutta l'app.
///
/// ⚠️ **Non `autoDispose`**: un database che si chiude e riapre a ogni
/// schermata paga l'apertura del file ogni volta, e su un telefono lento si
/// vede. Vive quanto l'app.
final archivioSaluteProvider = Provider<ArchivioSalute>((ref) {
  final archivio = ArchivioSalute();

  ref.onDispose(archivio.close);

  return archivio;
});

final ponteSaluteProvider = Provider<PonteSalute>(
  (ref) => PonteSalute(ref.watch(archivioSaluteProvider)),
);

/// Le calorie bruciate con l'attività in un giorno, lette da Google Health —
/// FASE 1.
///
/// 🚨 **Non escono mai da questo telefono.** Vivono in `ArchivioSalute` (che
/// finisce nel backup) e la somma con l'obiettivo calorico si fa **a runtime**,
/// qui nell'app: il server non le vede e non deve vederle.
///
/// 💡 `family` sul giorno perché la scheda cibo si può sfogliare indietro, e
/// il numero è quello **di quel giorno** — non quello di oggi mostrato accanto a
/// una data di tre giorni fa.
final kcalAttiveDelGiornoProvider = FutureProvider.autoDispose
    .family<int, DateTime>((ref, giorno) async {
      return ref.watch(archivioSaluteProvider).kcalAttiveDi(giorno);
    });

/// Le calorie attive **di oggi**.
///
/// ── 🚨 Perché un provider a parte e non `…DelGiorno(DateTime.now())` ──
///
/// **Perché quella riga non funziona, e non lo dice.** La chiave di una `family`
/// è il valore passato: `DateTime.now()` cambia a **ogni millisecondo**, quindi
/// ogni `build` creava un provider **nuovo** — appena nato, quindi in
/// caricamento, quindi `valueOrNull == null`, quindi `?? 0`.
///
/// ⚠️ **Il numero non compariva mai**, e non c'era nessun errore da nessuna
/// parte: la schermata mostrava zero come se zero fosse la risposta. È il
/// difetto riferito dal committente la sera del 19/08 — *«nell'header della
/// pagina oggi non le somma e non le mostra»* — e la prima correzione non lo
/// aveva chiuso proprio per questo.
///
/// 💡 Qui la data si calcola **dentro**, e l'identità del provider è una sola.
/// La scheda cibo invece usa `…DelGiorno(day.date)`, che è stabile perché è la
/// giornata che si sta sfogliando — e infatti lì funzionava.
/// Le calorie attive per un elenco di giornate (`yyyy-mm-dd`) — 19/08/2026.
///
/// 🚨 Serve al **grafico**, che mostrava zero bruciate mentre l'intestazione
/// ne mostrava 680. Non erano due numeri diversi: erano **due fonti diverse** —
/// il grafico legge la serie del server, che le calorie dell'orologio non le ha
/// e non le puo' avere, perche' restano sul telefono.
///
/// 💡 La chiave e' la lista delle date **gia' formattate**, cosi' l'identita'
/// del provider e' stabile: e' l'errore che avevo fatto con `DateTime.now()`,
/// che cambiava a ogni millisecondo e teneva il provider per sempre in
/// caricamento.
final kcalAttivePerGiorniProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, giorniUnitiDaVirgole) async {
      final archivio = ref.watch(archivioSaluteProvider);
      final esito = <String, int>{};

      for (final etichetta in giorniUnitiDaVirgole.split(',')) {
        final giorno = DateTime.tryParse(etichetta);

        if (giorno == null) continue;

        esito[etichetta] = await archivio.kcalAttiveDi(giorno);
      }

      return esito;
    });

final kcalAttiveOggiProvider = FutureProvider.autoDispose<int>((ref) async {
  final adesso = DateTime.now();

  return ref.watch(
    kcalAttiveDelGiornoProvider(
      DateTime(adesso.year, adesso.month, adesso.day),
    ).future,
  );
});

/// Lo stato del collegamento con Health Connect.
class StatoSalute {
  const StatoSalute({
    this.collegato = false,
    this.inCorso = false,
    this.errore,
    this.ultimaSincronizzazione,
  });

  final bool collegato;
  final bool inCorso;
  final String? errore;
  final String? ultimaSincronizzazione;

  StatoSalute copyWith({
    bool? collegato,
    bool? inCorso,
    String? errore,
    String? ultimaSincronizzazione,
    bool azzeraErrore = false,
  }) => StatoSalute(
    collegato: collegato ?? this.collegato,
    inCorso: inCorso ?? this.inCorso,
    errore: azzeraErrore ? null : (errore ?? this.errore),
    ultimaSincronizzazione: ultimaSincronizzazione ?? this.ultimaSincronizzazione,
  );
}

/// Chi governa il collegamento e la sincronizzazione — S3.4 / A5.
class HealthController extends StateNotifier<StatoSalute> {
  HealthController(this._ponte, this._archivio, this._consensoSanitario)
    : super(const StatoSalute());

  final PonteSalute _ponte;
  final ArchivioSalute _archivio;

  /// Se la persona ha dato il consenso al trattamento dei dati sanitari — S9.
  ///
  /// 🚨 **È una funzione e non un `bool`** perché va riletta al momento del
  /// gesto: il consenso si revoca da un'altra schermata, e una copia presa
  /// all'avvio direbbe «sì» a chi ha appena detto di no.
  final Future<bool> Function() _consensoSanitario;

  /// Chiede il permesso e, se c'è, sincronizza subito.
  ///
  /// ⚠️ **Il permesso e la prima lettura vanno insieme.** Chiedere il permesso
  /// e poi lasciare la schermata vuota fino al giorno dopo fa sembrare che non
  /// sia successo niente, e la persona lo revoca.
  Future<void> collega() async {
    state = state.copyWith(inCorso: true, azzeraErrore: true);

    /*
     * 🚨 **Il consenso sanitario viene PRIMA del permesso di sistema** — A5/S9.
     *
     * `ConsentController` lo dichiarava già («senza il consenso sanitario non
     * si collega Health Connect») ⚠️ **e nessuno lo verificava**: la
     * dichiarazione stava nel dartdoc del server e il cancello non esisteva da
     * nessuna parte.
     *
     * L'ordine conta. Chiedere prima il permesso di Android e poi accorgersi
     * che manca il consenso significherebbe aver già aperto il dialogo di
     * sistema — che su Android, se rifiutato due volte, **non si ripropone
     * più**. Si sarebbe bruciata l'unica occasione per una verifica che si
     * poteva fare senza disturbare nessuno.
     */
    if (!await _consensoSanitario()) {
      state = state.copyWith(
        inCorso: false,
        collegato: false,
        errore: 'Prima serve il tuo consenso al trattamento dei dati sanitari: '
            'lo trovi in Profilo → Privacy e consensi.',
      );

      return;
    }

    final concesso = await _ponte.chiediPermessi();

    if (!concesso) {
      state = state.copyWith(
        inCorso: false,
        collegato: false,
        errore: 'Non è stato possibile collegare Health Connect. '
            'Se hai già rifiutato in passato, il permesso va riattivato dalle '
            'impostazioni di sistema.',
      );

      return;
    }

    /*
     * 🚨 30 giorni, non 7.
     *
     * Health Connect di serie lascia rileggere circa un mese indietro, e oltre
     * serve un permesso a parte che Google concede con parsimonia. Alla PRIMA
     * sincronizzazione si prende tutto quello che si puo': da li' in poi la
     * memoria lunga e' l'archivio locale, che accumula.
     *
     * ⚠️ La media di riferimento a sette giorni esiste comunque solo dopo
     * sette giorni di dati. Non e' un difetto, ma va detto — o sembrera' che
     * la funzione non parta.
     */
    final quanti = await _ponte.sincronizza(giorniIndietro: 30);

    state = state.copyWith(
      inCorso: false,
      collegato: true,
      ultimaSincronizzazione: DateFormat('d MMM, HH:mm', 'it').format(DateTime.now()),
      errore: quanti == 0
          ? 'Collegato, ma non è arrivato ancora nessun dato. '
              'Succede se il tuo orologio non ha ancora sincronizzato con il telefono.'
          : null,
      azzeraErrore: quanti > 0,
    );
  }

  /// Riprende i dati nuovi **senza chiedere niente a nessuno** — A5.
  ///
  /// ── 🚨 Il difetto che chiude ──────────────────────────────────────────
  ///
  /// Prima l'unico modo di aggiornare i dati era tornare su «Sonno e recupero»
  /// e ritoccare *Collega*. Chi lo faceva il primo giorno e non ci tornava più
  /// vedeva **per sempre** il sonno di quella notte: la scheda in cima a «Oggi»
  /// mostrava un dato vecchio senza dire che era vecchio, ed è il modo più
  /// rapido per far smettere di fidarsi di un numero.
  ///
  /// ── ⚠️ Perché non chiede il permesso ──────────────────────────────────
  ///
  /// `chiediPermessi()` apre il dialogo di sistema, e questo metodo gira
  /// all'avvio: aprirlo lì sarebbe la cosa che il dartdoc di `PonteSalute`
  /// vieta esplicitamente — un permesso chiesto prima che si capisca a cosa
  /// serve viene negato, e su Android un rifiuto ripetuto **non si ripropone
  /// più**.
  ///
  /// Perciò qui si guarda solo se il permesso **c'è già**: se manca, non
  /// succede niente e la persona lo concederà dalla schermata che glielo
  /// spiega.
  ///
  /// 💡 Sette giorni e non trenta: è la finestra della media di riferimento, e
  /// riprendere un mese a ogni avvio costerebbe tempo per dati che l'archivio
  /// ha già.
  Future<void> aggiornaInSilenzio() async {
    // Anche qui il consenso viene prima: se è stato revocato, l'app smette di
    // leggere subito, non alla prossima volta che qualcuno tocca «collega».
    if (!await _consensoSanitario()) return;
    if (!await _ponte.permessiGiaConcessi()) return;

    final quanti = await _ponte.sincronizza();

    if (!mounted) return;

    state = state.copyWith(
      collegato: true,
      ultimaSincronizzazione: quanti > 0
          ? DateFormat('d MMM, HH:mm', 'it').format(DateTime.now())
          : state.ultimaSincronizzazione,
    );
  }

  /// Cancella tutto quello che c'è sul telefono.
  ///
  /// 🚨 Con i dati in locale il server non può cancellarli per conto di
  /// nessuno: **questo è l'unico modo che una persona ha di liberarsene** senza
  /// disinstallare l'app.
  Future<void> cancellaTutto() async {
    state = state.copyWith(inCorso: true, azzeraErrore: true);

    await _archivio.svuota();

    state = state.copyWith(inCorso: false, ultimaSincronizzazione: null);
  }
}

final healthControllerProvider =
    StateNotifierProvider<HealthController, StatoSalute>(
  (ref) => HealthController(
    ref.watch(ponteSaluteProvider),
    ref.watch(archivioSaluteProvider),

    /*
     * Il consenso si **rilegge** a ogni gesto, e non si cattura una volta: si
     * revoca da un'altra schermata, e una copia presa all'avvio direbbe «sì» a
     * chi ha appena detto di no.
     *
     * 💡 La regola vive tutta in `consensoSaluteProvider` — compreso il
     * «in dubbio è no» — perché la stessa domanda se la fa anche
     * `recuperoProvider`, e due implementazioni divergono sempre.
     */
    () => ref.read(consensoSaluteProvider.future),
  ),
);

/// La risincronizzazione d'avvio — A5.
///
/// 🚨 **Non è `autoDispose`, ed è il motivo per cui gira una volta sola** per
/// vita dell'app: se lo fosse, ogni volta che l'ultima schermata interessata
/// sparisce il provider morirebbe e la sincronizzazione ripartirebbe al
/// ritorno — cioè a ogni cambio di scheda.
final avvioSaluteProvider = FutureProvider<void>(
  (ref) => ref.read(healthControllerProvider.notifier).aggiornaInSilenzio(),
);
