import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/notifications/notifications.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../../core/ui/miniatura.dart';
import '../data/session_models.dart';
import '../rest_timer.dart';
import '../session_controller.dart';
import '../training_controller.dart';
import 'widgets/rest_bar.dart';

/// Il player di allenamento — C9.
///
/// È il pezzo che rende l'app usabile **in palestra**, e le sue scelte vengono
/// tutte da lì:
///
/// - lo **schermo resta acceso**: sbloccare il telefono con le mani sudate fra
///   una serie e l'altra è il modo più rapido per far smettere di usarlo;
/// - il **cronometro si calcola da `started_at`**, non incrementando un
///   contatore: in background i tick non arrivano, e al ritorno la durata
///   risulterebbe più corta di quella vera;
/// - si può **aggiungere un esercizio scrivendone il nome**: in sala la scheda
///   non corrisponde quasi mai alla realtà, fra macchine occupate e sostituzioni
///   al volo;
/// - ogni «OK» **scrive subito sul server**, e la scrittura è un UPSERT:
///   rimandarla su rete instabile non duplica niente.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({required this.sessionId, super.key});

  final int sessionId;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final _riposo = RestTimer();

  List<PlayerExercise> _esercizi = [];
  bool _pronto = false;
  bool _permessoChiesto = false;
  bool _modificato = false;
  bool _chiusura = false;
  String? _errore;

  Timer? _cronometro;
  DateTime? _inizio;
  int? _planId;
  String? _planName;

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
  void dispose() {
    _cronometro?.cancel();
    _riposo.dispose();

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

      final righe = <PlayerExercise>[];

      // 1. Gli esercizi previsti dalla scheda, con dentro ciò che è già stato
      //    registrato: riaprendo una sessione interrotta si ritrova tutto.
      if (sessione.planId != null) {
        final piano = await ref.read(
          planDetailProvider(sessione.planId!).future,
        );

        for (final riga in piano.exercises) {
          righe.add(
            PlayerExercise(
              name: riga.name,
              reps: _repsDa(riga.prescription),
              restSec: riga.restSec ?? 90,
              targetWeight: riga.targetWeight,
              notes: riga.notes,
              imageUrl: riga.imageUrl,
              rows: const [],
            ),
          );
        }
      }

      _riempiConIlGiaFatto(righe, sessione);

      if (mounted) {
        setState(() {
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

  /// Il primo numero di una prescrizione: «8-12» → 8, «cedimento» → `null`.
  ///
  /// Serve a precompilare la riga della serie con un punto di partenza
  /// ragionevole. Il valore prescritto resta comunque visibile per intero fra i
  /// parametri dell'esercizio.
  static int? _primoNumero(String? prescrizione) {
    if (prescrizione == null) return null;

    final trovato = RegExp(r'\d+').firstMatch(prescrizione);

    return trovato == null ? null : int.tryParse(trovato.group(0)!);
  }

  /// Le ripetizioni prescritte, estratte da «3 × 8-12».
  ///
  /// ⚠️ La prescrizione arriva **già composta** dal backend perché app e
  /// pannello mostrino la stessa cosa; qui serve solo la parte delle
  /// ripetizioni per precompilare le righe.
  static String? _repsDa(String prescrizione) {
    final parti = prescrizione.split('×');

    return parti.length > 1 ? parti.last.trim() : null;
  }

  /// Fonde le serie già registrate con gli esercizi previsti.
  void _riempiConIlGiaFatto(
    List<PlayerExercise> righe,
    WorkoutSession sessione,
  ) {
    final perEsercizio = <String, List<LoggedSet>>{};

    for (final serie in sessione.sets) {
      perEsercizio.putIfAbsent(serie.exerciseName, () => []).add(serie);
    }

    for (final riga in righe) {
      final fatte = perEsercizio.remove(riga.name) ?? const <LoggedSet>[];

      riga.exerciseId = fatte.isNotEmpty ? fatte.first.exerciseId : null;
      riga.rows = _righeDa(fatte, riga);
    }

    // Gli esercizi registrati **fuori scheda**: ci sono e vanno mostrati, o
    // sparirebbero dalla schermata pur essendo nel database.
    for (final voce in perEsercizio.entries) {
      final riga = PlayerExercise(
        name: voce.key,
        exerciseId: voce.value.first.exerciseId,
        restSec: voce.value.first.restSec ?? 90,
        rows: const [],
      );

      riga.rows = _righeDa(voce.value, riga);
      righe.add(riga);
    }
  }

  List<PlayerSet> _righeDa(List<LoggedSet> fatte, PlayerExercise riga) {
    final perNumero = {for (final s in fatte) s.setNumber: s};
    final quante = fatte.isEmpty ? 3 : fatte.length;
    final totale = perNumero.keys.isEmpty
        ? quante
        : (perNumero.keys.reduce((a, b) => a > b ? a : b));

    return [
      for (var i = 1; i <= totale; i++)
        PlayerSet(
          setNumber: i,
          // 🚨 `int.tryParse('8-12')` da' **null**: con una prescrizione a
          // intervallo — cioe' quasi sempre — il campo restava vuoto e le
          // ripetizioni andavano riscritte a ogni serie. Si prende il primo
          // numero: da «8-12» si parte da 8, da «cedimento» non si parte.
          reps: perNumero[i]?.reps ?? _primoNumero(riga.reps),
          weight: perNumero[i]?.weight ?? riga.targetWeight,
          done: perNumero.containsKey(i),
        ),
    ];
  }

  // ───────────────────────── azioni ─────────────────────────

  Future<void> _ok(PlayerExercise esercizio, PlayerSet riga) async {
    if (esercizio.name.trim().isEmpty) {
      _avvisa('Dai un nome all\'esercizio prima di registrare la serie.');

      return;
    }

    final eraFatta = riga.done;

    setState(() => riga.done = true);

    try {
      final id = await ref
          .read(sessionActionsProvider)
          .logSet(
            sessionId: widget.sessionId,
            setNumber: riga.setNumber,
            exerciseId: esercizio.exerciseId,
            exerciseName: esercizio.name.trim(),
            reps: riga.reps,
            weight: riga.weight,
            restSec: esercizio.restSec,
          );

      esercizio.exerciseId = id;

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

        await _riposo.avvia(esercizio.restSec);
      }
    } on Object catch (error) {
      // 🚨 Si torna indietro sulla spunta. Lasciarla verde su una serie che il
      // server non ha ricevuto farebbe credere di aver registrato qualcosa che
      // non c'è — e ci si accorge solo giorni dopo, guardando lo storico.
      setState(() => riga.done = eraFatta);

      _avvisa(ApiClient.unwrapError(error).message);
    }
  }

  void _avvisa(String messaggio) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(messaggio)));
  }

  void _aggiungiEsercizio() {
    setState(() {
      _esercizi.add(PlayerExercise(name: '', rows: [PlayerSet(setNumber: 1)]));
      _modificato = true;
    });
  }

  void _aggiungiSerie(PlayerExercise esercizio) {
    setState(() {
      final ultima = esercizio.rows.isEmpty ? null : esercizio.rows.last;

      esercizio.rows.add(
        PlayerSet(
          setNumber: esercizio.rows.length + 1,
          reps: ultima?.reps,
          weight: ultima?.weight,
        ),
      );
    });
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

    // Se durante la seduta la scheda è cambiata, si chiede se salvarla — ma
    // **solo se è sua**: proporlo per la scheda del trainer prometterebbe una
    // cosa che il server rifiuterà con un 403.
    if (_modificato && _planId != null) {
      final piano = await ref.read(planDetailProvider(_planId!).future);

      if (piano.editable && mounted) {
        final salva = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Salvare le modifiche alla scheda?'),
            content: const Text(
              'Hai cambiato gli esercizi durante l\'allenamento.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sì, salva'),
              ),
            ],
          ),
        );

        if (salva == true) await _salvaScheda();
      }
    }

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

  Future<void> _salvaScheda() async {
    try {
      await ref
          .read(planActionsProvider)
          .update(
            id: _planId!,
            name: _planName ?? 'Scheda',
            exercises: _esercizi
                .where((e) => e.name.trim().isNotEmpty)
                .map(
                  (e) => {
                    'name': e.name.trim(),
                    'sets': e.rows.length,
                    'reps': e.reps,
                    'rest_sec': e.restSec,
                    'target_weight': e.targetWeight,
                    'notes': e.notes,
                  },
                )
                .toList(),
          );
    } on Object catch (error) {
      _avvisa('Scheda non salvata: ${ApiClient.unwrapError(error).message}');
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
                for (final esercizio in _esercizi)
                  _CardEsercizio(
                    esercizio: esercizio,
                    onOk: (riga) => _ok(esercizio, riga),
                    onAggiungiSerie: () => _aggiungiSerie(esercizio),
                    onCambiato: () => setState(() => _modificato = true),
                    onRimuovi: () => setState(() {
                      _esercizi.remove(esercizio);
                      _modificato = true;
                    }),
                  ),
                const SizedBox(height: Gap.sm),
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
}

/// «72.5» invece di «72.5000», «60» invece di «60.0».
///
/// A livello di file e non dentro una classe: la usano sia la riga della serie
/// sia i parametri prescritti, e due copie della stessa formattazione sono due
/// modi diversi di scrivere lo stesso peso nella stessa schermata.
String _pulito(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Un esercizio con le sue righe-serie.
class _CardEsercizio extends StatefulWidget {
  const _CardEsercizio({
    required this.esercizio,
    required this.onOk,
    required this.onAggiungiSerie,
    required this.onCambiato,
    required this.onRimuovi,
  });

  final PlayerExercise esercizio;
  final void Function(PlayerSet) onOk;
  final VoidCallback onAggiungiSerie;
  final VoidCallback onCambiato;
  final VoidCallback onRimuovi;

  @override
  State<_CardEsercizio> createState() => _CardEsercizioState();
}

class _CardEsercizioState extends State<_CardEsercizio> {
  late final _nome = TextEditingController(text: widget.esercizio.name);
  late final _repsPreviste = TextEditingController(
    text: widget.esercizio.reps ?? '',
  );
  late final _recupero = TextEditingController(
    text: widget.esercizio.restSec.toString(),
  );
  late final _pesoObiettivo = TextEditingController(
    text: widget.esercizio.targetWeight == null
        ? ''
        : _pulito(widget.esercizio.targetWeight!),
  );

  /// I parametri prescritti si aprono su richiesta.
  ///
  /// Chiusi di serie: mentre ci si allena servono le righe delle serie, non
  /// tre campi di configurazione — che occuperebbero lo spazio di due esercizi
  /// per ogni scheda.
  bool _apertoIlDettaglio = false;

  @override
  void dispose() {
    _nome.dispose();
    _repsPreviste.dispose();
    _recupero.dispose();
    _pesoObiettivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.esercizio;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.md),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // C23 — durante l'allenamento un'immagine dice quale movimento
                // molto piu' in fretta di un nome, e si guarda da lontano.
                Miniatura(url: e.imageUrl, etichetta: e.name, lato: 40),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: TextField(
                    controller: _nome,
                    decoration: const InputDecoration(
                      hintText: 'Nome esercizio',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    onChanged: (v) {
                      e.name = v;
                      // Cambiando nome l'esercizio non è più quello di prima:
                      // azzerare l'id costringe il server a riconciliare il
                      // nome nuovo, invece di scrivere sotto quello vecchio.
                      e.exerciseId = null;
                      widget.onCambiato();
                    },
                  ),
                ),
                // 🚨 La matita, come sull'app homelab.
                //
                // I parametri prescritti — ripetizioni, recupero, peso
                // obiettivo — si cambiano **mentre ci si allena**, perché è lì
                // che ci si accorge che 8 erano troppe o che 90 secondi non
                // bastano. Doverli correggere dopo, dall'editor delle schede,
                // vuol dire non correggerli mai.
                IconButton(
                  onPressed: () =>
                      setState(() => _apertoIlDettaglio = !_apertoIlDettaglio),
                  icon: Icon(
                    _apertoIlDettaglio
                        ? Icons.expand_less_rounded
                        : Icons.edit_outlined,
                  ),
                  tooltip: 'Parametri',
                ),
                IconButton(
                  onPressed: widget.onRimuovi,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Togli dall\'allenamento',
                ),
              ],
            ),

            if (!_apertoIlDettaglio &&
                (e.reps != null || e.targetWeight != null))
              Text(
                [
                  if (e.reps != null) '${e.rows.length} × ${e.reps}',
                  if (e.targetWeight != null) '${e.targetWeight} kg',
                  '${e.restSec}s di recupero',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),

            if (_apertoIlDettaglio)
              Padding(
                padding: const EdgeInsets.only(top: Gap.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _repsPreviste,
                        decoration: const InputDecoration(
                          labelText: 'Ripetizioni',
                          hintText: '8-12',
                          isDense: true,
                        ),
                        // ⚠️ Testo e non numero: «8-12», «cedimento» e «max»
                        // sono prescrizioni legittime, ed è il motivo per cui
                        // anche a database `reps` è una stringa.
                        onChanged: (v) {
                          e.reps = v.trim().isEmpty ? null : v.trim();
                          widget.onCambiato();
                        },
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: TextField(
                        controller: _recupero,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Recupero',
                          suffixText: 's',
                          isDense: true,
                        ),
                        onChanged: (v) {
                          e.restSec = int.tryParse(v.trim()) ?? e.restSec;
                          widget.onCambiato();
                        },
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: TextField(
                        controller: _pesoObiettivo,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Peso',
                          suffixText: 'kg',
                          isDense: true,
                        ),
                        onChanged: (v) {
                          e.targetWeight = double.tryParse(
                            v.trim().replaceAll(',', '.'),
                          );
                          widget.onCambiato();
                        },
                      ),
                    ),
                  ],
                ),
              ),

            if ((e.notes ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Text(e.notes!, style: theme.textTheme.bodySmall),
              ),

            const SizedBox(height: Gap.sm),

            for (final riga in e.rows)
              _RigaSerie(riga: riga, onOk: () => widget.onOk(riga)),

            TextButton.icon(
              onPressed: widget.onAggiungiSerie,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Serie'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RigaSerie extends StatefulWidget {
  const _RigaSerie({required this.riga, required this.onOk});

  final PlayerSet riga;
  final VoidCallback onOk;

  @override
  State<_RigaSerie> createState() => _RigaSerieState();
}

class _RigaSerieState extends State<_RigaSerie> {
  late final _reps = TextEditingController(
    text: widget.riga.reps?.toString() ?? '',
  );
  late final _peso = TextEditingController(
    text: widget.riga.weight == null ? '' : _pulito(widget.riga.weight!),
  );

  /// 🚨 **Toccando il campo, il valore si seleziona tutto.**
  ///
  /// I campi arrivano già riempiti con quello che prescrive la scheda — ed è
  /// giusto: nove volte su dieci il peso è quello, e non si deve riscrivere
  /// niente. Ma quando **non** è quello, con il cursore piazzato in mezzo alle
  /// cifre bisognerebbe cancellarle una a una con le mani sudate, in piedi
  /// davanti a un bilanciere. Selezionandole tutte, la prima cifra digitata le
  /// sostituisce: è come trovare il campo vuoto, ma se si tocca per sbaglio e
  /// si tocca altrove il valore prescritto è ancora lì.
  final FocusNode _fuocoReps = FocusNode();
  final FocusNode _fuocoPeso = FocusNode();

  @override
  void initState() {
    super.initState();

    _fuocoReps.addListener(() => _seleziona(_fuocoReps, _reps));
    _fuocoPeso.addListener(() => _seleziona(_fuocoPeso, _peso));
  }

  void _seleziona(FocusNode fuoco, TextEditingController controller) {
    if (!fuoco.hasFocus || controller.text.isEmpty) return;

    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  @override
  void dispose() {
    _reps.dispose();
    _peso.dispose();
    _fuocoReps.dispose();
    _fuocoPeso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riga = widget.riga;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${riga.setNumber}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _reps,
              focusNode: _fuocoReps,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'rip.',
                isDense: true,
              ),
              onChanged: (v) => riga.reps = int.tryParse(v),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: TextField(
              controller: _peso,
              focusNode: _fuocoPeso,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'kg', isDense: true),
              onChanged: (v) =>
                  riga.weight = double.tryParse(v.replaceAll(',', '.')),
            ),
          ),
          const SizedBox(width: Gap.sm),
          // Il pulsante resta premibile anche dopo: correggere una serie
          // registrata per sbaglio con il peso di quella prima capita di
          // continuo, e l'UPSERT lo permette senza duplicare.
          IconButton.filled(
            onPressed: widget.onOk,
            isSelected: riga.done,
            icon: Icon(
              riga.done ? Icons.check_rounded : Icons.done_outline_rounded,
            ),
            style: riga.done
                ? null
                : IconButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                  ),
          ),
        ],
      ),
    );
  }
}
