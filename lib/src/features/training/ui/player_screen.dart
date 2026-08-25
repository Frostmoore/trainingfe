/// Il player di allenamento — C9, rifatto in 3b-E (25/08/2026).
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«La pagina dell'allenamento deve mostrare gli esercizi come quella
/// dell'editor delle schede, con una matita per modificare nome e muscoli»* ·
/// *«Tutte le serie … come righe separate, con campi precompilati secondo quanto
/// registrato nella scheda»* · *«tutti i campi devono poter essere modificati …
/// e ogni modifica deve aggiornare la scheda»* · *«deve essere possibile
/// riorganizzare gli esercizi»* · *«rimuovere gli esercizi o singole serie»* ·
/// *«aggiungere nuovi esercizi … l'interfaccia di inserimento deve essere
/// esattamente identica a quella dell'editor»* · *«il tempo di riposo deve
/// seguire quello indicato nella scheda»* · *«Tutto deve funzionare bene (adesso
/// funziona bene, quindi fai in modo che non si rompa)»*.
///
/// ══ 🚨 IL VINCOLO CHE QUESTA SCHERMATA HA E LE ALTRE NO ═══════════════════
///
/// È l'unica dell'app che si usa **con le mani sudate, di fretta, fra una serie
/// e l'altra**, spesso col telefono appoggiato da qualche parte. ⛔ Quello che
/// altrove è un difetto di gusto, qui è **una serie che non si registra**.
///
/// Le scelte vengono tutte da lì:
///
/// - lo **schermo resta acceso**: sbloccare il telefono con le mani sudate fra
///   una serie e l'altra è il modo più rapido per far smettere di usarlo;
/// - il **cronometro si calcola da `started_at`**, non incrementando un
///   contatore: in background i tick non arrivano, e al ritorno la durata
///   risulterebbe più corta di quella vera;
/// - si può **aggiungere un esercizio scrivendone il nome**: in sala la scheda
///   non corrisponde quasi mai alla realtà, fra macchine occupate e sostituzioni
///   al volo;
/// - ogni spunta **scrive subito** in archivio, e la scrittura è un UPSERT:
///   ripremerla non duplica niente, la corregge.
///
/// ══ 🚨 E DA 3b-E LA SCHEDA SI MODIFICA DA QUI, SENZA CHIEDERE ═════════════
///
/// 📌 *«ricordati che TUTTE LE MODIFICHE fatte durante l'allenamento devono
/// modificare la scheda»*.
///
/// ⛔ Prima c'era una finestra a fine seduta — *«Salvare le modifiche alla
/// scheda?»* — e non andava bene per due ragioni opposte: chi diceva «no» per
/// abitudine perdeva le correzioni fatte in sala, e chi diceva «sì» senza
/// leggere si è visto **sparire due esercizi** (B.15, 24/08).
///
/// 💡 Adesso ogni modifica si scrive man mano. ⚠️ Il gesto che toglie qualcosa
/// resta l'unico con una rete: togliendo un esercizio compare **Annulla**, e
/// l'undo è più onesto di una domanda a fine allenamento su una cosa fatta
/// venti minuti prima.
///
/// ⛔ **Sulle schede del trainer non si scrive**: restano com'è arrivata, e la
/// riga in cima lo dice invece di far credere il contrario.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/notifications/notifications.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../health/health_controller.dart';
import '../data/allenamento_in_corso.dart';
import '../data/catalogo_esercizi.dart';
import '../data/serie_prevista.dart';
import '../rest_timer.dart';
import '../session_controller.dart';
import '../training_controller.dart';
import 'widgets/card_esercizio_scrittura.dart';
import 'widgets/rest_bar.dart';
import 'widgets/scelta_muscoli.dart';
import 'widgets/spunta_della_serie.dart';

/// Il recupero di ripiego, quando la scheda non lo dice da nessuna parte.
///
/// ⚠️ Novanta secondi: è quello che c'era prima di 3b-E, e cambiarlo qui
/// cambierebbe di nascosto il riposo di tutte le schede scritte finora.
const int recuperoDiRipiego = 90;

/// Quanto si aspetta prima di scrivere la scheda, dopo l'ultimo tasto.
///
/// 🚨 Non zero: scrivere l'archivio a ogni carattere vorrebbe dire una
/// transazione per tasto mentre si compila un peso. ⚠️ E non troppo: quello che
/// si è scritto e non è ancora finito su disco è quello che si perde se il
/// sistema chiude l'app mentre è in tasca.
const Duration attesaPrimaDiScrivere = Duration(milliseconds: 700);

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({required this.sessionId, super.key});

  final int sessionId;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final _riposo = RestTimer();

  List<EsercizioInAllenamento> _esercizi = [];
  bool _pronto = false;
  bool _permessoChiesto = false;
  bool _chiusura = false;
  String? _errore;

  Timer? _cronometro;
  Timer? _scrittura;
  DateTime? _inizio;
  int? _planId;
  String? _planName;

  /// La scheda **com'è scritta in archivio**, per rattopparla senza perdere
  /// niente — vedi `schedaConGliEsercizi`.
  Map<String, dynamic> _scheda = const {};

  /// Vero solo per le schede proprie: su quelle del trainer non si scrive.
  bool _modificabile = false;

  @override
  void initState() {
    super.initState();

    WakelockPlus.enable();

    _cronometro = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _carica();
  }

  @override
  void deactivate() {
    /*
     * 🚨 **L'ultima scrittura si fa uscendo, non si aspetta il timer.**
     *
     * ⛔ Senza questo, quello che si è battuto negli ultimi 700 ms se ne va con
     * la schermata: il tasto «indietro» premuto subito dopo aver corretto un
     * peso lo butterebbe via — e chi l'ha corretto non ha nessun modo di
     * saperlo.
     */
    _scrittura?.cancel();
    unawaited(_scriviLaScheda());

    super.deactivate();
  }

  @override
  void dispose() {
    _cronometro?.cancel();
    _scrittura?.cancel();
    _riposo.dispose();

    for (final e in _esercizi) {
      e.dispose();
    }

    // 🚨 Sempre, anche in caso di errore: lasciare il wakelock acceso
    // significa un telefono che non si spegne più finché non si riavvia l'app,
    // e la batteria finita a metà giornata.
    WakelockPlus.disable();

    super.dispose();
  }

  Future<void> _carica() async {
    try {
      final sessione = await ref.read(sessionProvider(widget.sessionId).future);

      _inizio = sessione.startedAt;
      _planId = sessione.planId;
      _planName = sessione.planName;

      var scheda = const <String, dynamic>{};

      if (sessione.planId != null) {
        /*
         * ══ 🚨 SI LEGGE IL JSON GREZZO, NON `PlanExercise` ═════════════════
         *
         * ⛔ È la stessa scelta dell'editor (3b-D), e per lo stesso motivo: il
         * modello dell'app **non porta i muscoli scritti dentro la scheda**.
         * Rileggendo da lì e riscrivendo, `muscle_group` e `secondary_muscles`
         * sparirebbero al primo allenamento — 🚨 e non darebbero nessun errore:
         * si spegnerebbe solo la figura, giorni dopo.
         */
        final locale = await ref
            .read(archivioSaluteProvider)
            .laScheda(sessione.planId!);

        if (locale != null) {
          scheda = (json.decode(locale.scheda) as Map).cast<String, dynamic>();
          _modificabile = locale.mia;
          _planName = locale.nome;
        }
      }

      final righe = eserciziDellAllenamento(
        scheda: scheda,
        fatte: sessione.sets,
      );

      if (mounted) {
        setState(() {
          _scheda = scheda;
          _esercizi = righe;
          _pronto = true;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _errore = ApiClient.unwrapError(error).message;
          _pronto = true;
        });
      }
    }
  }

  // ───────────────────────── la scheda si scrive ─────────────────────────

  /// Ridisegna e **programma** la scrittura: per quello che si batte a mano.
  void _cambiato() {
    setState(() {});

    _scrittura?.cancel();
    _scrittura = Timer(attesaPrimaDiScrivere, () => unawaited(_scriviLaScheda()));
  }

  /// Ridisegna e scrive **subito**: per i gesti, che sono pochi e definitivi.
  ///
  /// 💡 Aggiungere, togliere, spostare un esercizio o spuntare una serie non è
  /// una cosa che si «sta ancora facendo»: aspettare mezzo secondo servirebbe
  /// solo ad avere una finestra in cui perderlo.
  void _cambiatoSubito() {
    setState(() {});

    _scrittura?.cancel();
    unawaited(_scriviLaScheda());
  }

  Future<void> _scriviLaScheda() async {
    final id = _planId;

    // ⛔ Niente scheda, o scheda del trainer: non c'è niente su cui scrivere.
    if (id == null || !_modificabile) return;

    try {
      final rifatta = schedaConGliEsercizi(_scheda, [
        for (final e in _esercizi)
          if (e.nome.text.trim().isNotEmpty) e.versoIlDato(),
      ]);

      _scheda = rifatta;

      /*
       * 🚨 **Si legge il provider PRIMA di aspettare.** L'ultima scrittura parte
       * da `deactivate()`, cioè mentre la schermata se ne sta andando: quello
       * che c'è dopo l'`await` gira su un widget che non esiste più, e usare il
       * `ref` di casa lì lancerebbe *«Cannot use ref after dispose»*.
       *
       * 💡 `PlanActions` vive nel contenitore e non nel widget: dentro di lui
       * la sequenza «scrivi, poi fai rileggere» si completa comunque.
       */
      await ref
          .read(planActionsProvider)
          .riscrivi(id: id, nome: _planName ?? 'Scheda', scheda: rifatta);
    } on Object catch (error) {
      /*
       * ⚠️ Si avvisa e basta: l'allenamento **continua**. Le serie stanno in un
       * archivio diverso e sono già scritte; qui si è persa solo la modifica
       * alla prescrizione, e fermare la seduta per quello sarebbe sproporzionato.
       */
      _avvisa('Scheda non aggiornata: ${ApiClient.unwrapError(error).message}');
    }
  }

  // ───────────────────────── azioni ─────────────────────────

  Future<void> _ok(EsercizioInAllenamento esercizio, int indice) async {
    if (esercizio.nome.text.trim().isEmpty) {
      _avvisa('Dai un nome all\'esercizio prima di registrare la serie.');

      return;
    }

    /*
     * ══ 🚨 I MUSCOLI PRIMA DELLA PRIMA SERIE — 3b-A.3.5, 24/08/2026 ═══════
     *
     * ⛔ Da A.3.5 il server **rifiuta** di creare un esercizio senza muscoli.
     * Senza questa guardia la prima serie di un movimento inventato prenderebbe
     * un 422 rosso a metà allenamento — e la spunta tornerebbe indietro senza
     * che si capisca perché.
     *
     * 💡 Chiedere **prima** costa un tocco e succede una volta sola: solo per
     * un nome che il catalogo non conosce, e solo la prima volta che si scrive.
     */
    if (!await _muscoliSeServono(esercizio)) return;

    final riga = esercizio.serieFatte[indice];
    final eraFatta = riga.fatta;

    // 🚨 Il numero con cui era già stata registrata, o la posizione di adesso:
    // vedi `SerieInAllenamento.numeroRegistrato`.
    final numero = riga.numeroRegistrato ?? indice + 1;

    setState(() {
      riga.fatta = true;
      riga.numeroRegistrato = numero;
    });

    try {
      final id = await ref
          .read(sessionActionsProvider)
          .logSet(
            sessionId: widget.sessionId,
            setNumber: numero,
            exerciseId: esercizio.exerciseId,
            exerciseName: esercizio.nome.text.trim(),
            muscoli: esercizio.muscoli,
            reps: int.tryParse(riga.ripetizioni.text.trim()),

            /*
             * ⚠️ **Il peso solo se è un peso.** Con `Iso.` in quella colonna ci
             * sono i **secondi** di tenuta, e scriverli in `pesoKg` vorrebbe
             * dire 40 chili in uno storico che nessuno rileggerà mai con
             * sospetto.
             *
             * ⏳ **Debito dichiarato**: i secondi di isometria nello storico non
             * ci finiscono affatto — `SerieSeduta` non ha un campo per loro.
             */
            weight: esercizio.carico == CaricoDellEsercizio.peso
                ? double.tryParse(riga.carico.text.trim().replaceAll(',', '.'))
                : null,
            restSec: _recuperoDi(esercizio, indice),
          );

      /*
       * ⚠️ **Solo un id vero.** `logSet` risponde con un id **negativo**
       * provvisorio quando la rete non c'è (B.16.10). 🚨 Scrivendolo
       * nell'esercizio finirebbe dentro la scheda al prossimo salvataggio, e
       * `catalogo.perId(-12345)` non trova niente: muscoli spenti e MET perso,
       * per sempre e senza un errore.
       */
      if (id > 0) esercizio.exerciseId = id;

      // ⚠️ La spunta ha cambiato lo stato dell'esercizio: la scheda si riscrive
      // comunque, perché i numeri della riga possono essere stati corretti.
      _cambiatoSubito();

      // Il riposo parte solo la **prima** volta: correggere una serie già
      // registrata non è aver appena finito di spingere.
      if (!eraFatta) {
        // Il permesso si chiede QUI, non all'avvio dell'app: qui il motivo è
        // evidente («ti avviso quando finisce il recupero»), all'avvio no — e
        // un permesso chiesto senza contesto viene negato per sempre.
        if (!_permessoChiesto) {
          _permessoChiesto = true;
          await requestNotificationPermission();
        }

        await _riposo.avvia(_recuperoDi(esercizio, indice) ?? recuperoDiRipiego);
      }
    } on Object catch (error) {
      // 🚨 Si torna indietro sulla spunta. Lasciarla piena su una serie che non
      // è stata scritta farebbe credere di aver registrato qualcosa che non
      // c'è — e ci si accorge solo giorni dopo, guardando lo storico.
      setState(() => riga.fatta = eraFatta);

      _avvisa(ApiClient.unwrapError(error).message);
    }
  }

  /// Il recupero **di questa riga**, come lo dice la scheda — 3b-E.4.
  ///
  /// 📌 *«il tempo di riposo deve seguire quello indicato nella scheda»*.
  ///
  /// 💡 Adesso il campo è a schermo, sulla riga, e si corregge lì: novanta
  /// secondi fra le prime serie e due minuti prima dell'ultima è come sono
  /// scritte le schede vere.
  ///
  /// ⚠️ **Se questa riga non lo dice, lo dice la più vicina sopra.** Un campo
  /// lasciato vuoto sull'ultima serie non deve far tornare al ripiego di
  /// fabbrica una scheda che il recupero l'aveva dichiarato.
  int? _recuperoDi(EsercizioInAllenamento esercizio, int indice) {
    for (var i = indice; i >= 0; i--) {
      final s = int.tryParse(esercizio.righe[i].recupero.text.trim());

      if (s != null && s > 0) return s;
    }

    return null;
  }

  /// Chiede i muscoli se l'esercizio non è in catalogo. `false` = si annulla.
  Future<bool> _muscoliSeServono(EsercizioInAllenamento esercizio) async {
    // 💡 Un esercizio che viene dalla scheda ha già il suo id: esiste, e il
    // server i suoi muscoli li sa.
    if (esercizio.exerciseId != null || esercizio.muscoli != null) return true;

    final catalogo =
        ref.read(catalogoEserciziProvider).valueOrNull ??
        CatalogoEsercizi.vuoto;

    if (catalogo.perNome(esercizio.nome.text.trim()) != null) return true;

    if (!mounted) return false;

    final scelti = await chiediIMuscoli(
      context,
      nomeEsercizio: esercizio.nome.text.trim(),
    );

    if (scelti == null) {
      _avvisa(
        'Senza i muscoli l\'esercizio non si può aggiungere in libreria.',
      );

      return false;
    }

    esercizio.muscoli = scelti;

    return true;
  }

  void _avvisa(String messaggio) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(messaggio)));
  }

  void _aggiungiEsercizio() {
    _esercizi.add(EsercizioInAllenamento());
    _cambiatoSubito();
  }

  /// Toglie un esercizio, **con la rete sotto** — 3b-E.7.
  ///
  /// ══ 🚨 È IL GESTO CHE IL 24/08 HA FATTO SPARIRE DUE ESERCIZI ═════════════
  ///
  /// ⛔ Allora spariva a fine seduta, per un «sì» dato a una finestra che non
  /// diceva **quali**. 💡 Adesso sparisce subito, si vede sparire, e per
  /// dieci secondi c'è **Annulla**: chi ha toccato il cestino per sbaglio se ne
  /// accorge nel momento in cui succede, che è l'unico in cui può rimediare.
  ///
  /// ⚠️ L'esercizio **non si `dispose()`** finché l'undo è in piedi: i suoi
  /// controller devono essere ancora vivi per rimetterlo dov'era.
  void _rimuoviEsercizio(int indice) {
    final tolto = _esercizi.removeAt(indice);

    _cambiatoSubito();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('«${tolto.nome.text.trim()}» tolto dalla scheda'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Annulla',
            onPressed: () {
              _esercizi.insert(indice.clamp(0, _esercizi.length), tolto);
              _cambiatoSubito();
            },
          ),
        ),
      );
  }

  Future<void> _termina() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Concludere l\'allenamento?'),
        content: const Text('Le calorie verranno stimate automaticamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Concludi'),
          ),
        ],
      ),
    );

    if (conferma != true || !mounted) return;

    // ⚠️ L'ultima scrittura **prima** di chiudere: da qui in poi si va al
    // riepilogo e questa schermata non esiste più.
    _scrittura?.cancel();
    await _scriviLaScheda();

    if (!mounted) return;

    setState(() => _chiusura = true);

    try {
      await ref.read(sessionActionsProvider).finish(widget.sessionId);

      if (!mounted) return;

      // 🚨 **Si va al riepilogo, non si torna all'elenco.**
      //
      // `pushReplacement` e non `push`: il player non deve restare dietro, o
      // il tasto indietro riaprirebbe una sessione ormai chiusa. Ed e' li' che
      // si carica la foto e si correggono le calorie — le tre cose che dopo
      // cinque minuti non fa piu' nessuno.
      //
      // ⚠️ Quello di **go_router**, non `Navigator.pushReplacement`: spingendo
      // una `MaterialPageRoute` a mano, go_router continuerebbe a credere che
      // la rotta corrente sia il player, e «Fine» riporterebbe li' — su una
      // sessione ormai chiusa.
      context.pushReplacement(AppRoutes.riepilogo(widget.sessionId));
    } on Object catch (error) {
      setState(() => _chiusura = false);
      _avvisa(ApiClient.unwrapError(error).message);
    }
  }

  String get _durata {
    final inizio = _inizio;

    if (inizio == null) return '0:00';

    final s = DateTime.now().difference(inizio).inSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;

    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}'
        : '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_pronto) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: IntestazioneApp(
        titolo: _planName ?? 'Sessione libera',
        // ⏱️ Il cronometro della seduta: era la seconda riga del titolo, e
        // `sottotitolo` esiste esattamente per questo caso.
        sottotitolo: _durata,
        azioni: [
          TextButton(
            onPressed: _chiusura ? null : _termina,
            child: const Text('Concludi'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_errore != null)
            Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Text(
                _errore!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Gap.md),
              children: [
                /*
                 * ⚠️ **Si dice che qui non si scrive, invece di non scrivere e
                 * basta.** Su una scheda del trainer i campi restano
                 * modificabili — servono per registrare quello che si è
                 * davvero fatto — ma la prescrizione non cambia, e chi corregge
                 * un peso deve sapere che domani ritroverà quello di prima.
                 */
                if (_planId != null && !_modificabile)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.md),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Text(
                            'Scheda del tuo trainer: le modifiche valgono solo '
                            'per questo allenamento.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                /*
                 * ══ ↕️ GLI ESERCIZI SI SPOSTANO ANCHE QUI — 3b-E.3 ═════════
                 *
                 * 📌 *«deve essere possibile riorganizzare gli esercizi»*.
                 *
                 * 💡 In sala succede di continuo: la panca è occupata e si fa
                 * prima la schiena. ⚠️ Stessa disposizione dell'editor —
                 * `buildDefaultDragHandles: false` e la maniglia dentro la
                 * card — o il trascinamento partirebbe da qualunque punto e
                 * sposterebbe un esercizio mentre si prova a scrivere un peso.
                 */
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: (da, a) {
                    _esercizi.insert(a, _esercizi.removeAt(da));
                    _cambiatoSubito();
                  },
                  children: [
                    for (var i = 0; i < _esercizi.length; i++)
                      /*
                       * ══ 🚨 LA CHIAVE NON È UN'OTTIMIZZAZIONE — B.15 ══════
                       *
                       * 📌 Il committente, dopo un allenamento vero: *«ho
                       * cercato di rimuovere curl invertito, ma non mi è
                       * sparito dalla scheda quindi semplicemente l'ho
                       * fatto»*. E ne erano spariti **due**.
                       *
                       * ⛔ Senza chiave, Flutter abbina i figli **per
                       * posizione**: tolto l'elemento 8, la card che stava al 9
                       * riceve i dati dell'8 ma **si tiene il suo `State`** — e
                       * i controller restano quelli di prima. A schermo non
                       * cambia niente.
                       *
                       * 🚨 E il danno non è cosmetico: chi tocca «rimuovi» e
                       * non vede succedere niente **tocca di nuovo**, e il
                       * secondo tocco cancella il vicino che nel frattempo è
                       * scivolato lì.
                       *
                       * 💡 `ObjectKey` e non `ValueKey(nome)`: due esercizi
                       * possono chiamarsi uguale — o avere il nome vuoto,
                       * appena aggiunti — e una chiave che collide è peggio di
                       * nessuna chiave.
                       */
                      CardEsercizioScrittura(
                        key: ObjectKey(_esercizi[i]),
                        esercizio: _esercizi[i],
                        numero: i + 1,
                        posizione: i,
                        etichetta: _etichetta(i),
                        codaDellaRiga: (riga) => SpuntaDellaSerie(
                          fatta: _esercizi[i].serieFatte[riga].fatta,
                          onTocco: () => _ok(_esercizi[i], riga),
                        ),
                        onCambio: _cambiato,
                        onRimuovi: () => _rimuoviEsercizio(i),
                      ),
                  ],
                ),

                const SizedBox(height: Gap.sm),

                /*
                 * 📌 *«deve essere possibile aggiungere nuovi esercizi. In
                 * questo caso, l'interfaccia di inserimento deve essere
                 * esattamente identica a quella dell'editor delle schede»*.
                 *
                 * ✅ Lo è alla lettera: la card è **la stessa classe**, con
                 * l'elenco del catalogo mentre si scrive il nome e le pasticche
                 * dei muscoli. L'unica differenza è la spunta in fondo a ogni
                 * riga.
                 */
                OutlinedButton.icon(
                  onPressed: _aggiungiEsercizio,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Aggiungi esercizio'),
                ),

                // 🚨 Il pulsante grosso sta QUI, in fondo alla lista.
                //
                // Il «Concludi» nella barra in alto è un testo piccolo in un
                // angolo: finito l'ultimo esercizio si è in fondo allo schermo,
                // e l'azione ovvia dev'essere sotto il pollice. Con il solo
                // pulsante in alto la sessione resta aperta, e lo storico si
                // riempie di allenamenti che non finiscono mai.
                const SizedBox(height: Gap.lg),
                FilledButton.icon(
                  onPressed: _chiusura ? null : _termina,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Concludi allenamento'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: Gap.xl),
              ],
            ),
          ),

          // La barra del riposo sta in fondo e non copre il contenuto: fra una
          // serie e l'altra si guarda il telefono da lontano, appoggiato.
          RestBar(timer: _riposo),
        ],
      ),
    );
  }

  /// «Esercizio 2 · 1 di 3» — 3b-E.2.
  ///
  /// 💡 A che punto si è di **questo** esercizio è l'unica cosa che serve
  /// sapere guardando il telefono da un metro, appoggiato sulla panca. ⚠️ Il
  /// conteggio compare solo quando qualcosa è stato fatto: su un esercizio
  /// intatto un «0 di 3» sarebbe rumore.
  String _etichetta(int i) {
    final e = _esercizi[i];
    final fatte = e.quanteFatte;

    if (fatte == 0) return 'Esercizio ${i + 1}';

    return e.tuttoFatto
        ? 'Esercizio ${i + 1} · fatto'
        : 'Esercizio ${i + 1} · $fatte di ${e.righe.length}';
  }
}
