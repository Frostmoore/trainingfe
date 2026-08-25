/// Scrivere una scheda — C11, rifatta in 3b-D (25/08/2026).
///
/// ══ 🚨 COSA E' CAMBIATO, E PERCHE' NON ERA SOLO INTERFACCIA ═══════════════
///
/// ⛔ Fino a ieri un esercizio aveva **una** prescrizione e **un** peso validi
/// per tutte le serie. Il committente ha chiesto *«ogni serie deve avere
/// Ripetizioni, Peso (o niente o Iso.) e Recupero»*, e quella è una modifica al
/// **dato**, non alla schermata: adesso una serie è una riga.
///
/// 💡 Il modello sta in `data/serie_prevista.dart` e lo stato di scrittura in
/// `data/scheda_in_scrittura.dart` — qui dentro c'è solo la disposizione.
///
/// ── ⚠️ E le schede già scritte si aprono lo stesso ───────────────────────
///
/// 📌 *«è fondamentale che funzioni tutto correttamente e che le schede già
/// esistenti ricalchino questa nuova impostazione»*.
///
/// 🚨 Ci pensa `serieDellEsercizio()`: una scheda vecchia — o una appena
/// arrivata dal trainer, che dal server arriva **ancora** nel formato vecchio —
/// si apre qui già in righe. ⛔ **Non c'è nessun ramo «se è vecchia»** in questa
/// schermata, ed è voluto: quel ramo è il posto in cui i difetti si nascondono.
///
/// ── 🚨 Ci si arriva solo per le schede proprie ───────────────────────────
///
/// Quelle del trainer hanno `editable = false` e l'app non mostra il pulsante.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../health/health_controller.dart';
import '../data/catalogo_esercizi.dart';
import '../data/gruppo_muscolare.dart';
import '../data/scheda_in_scrittura.dart';
import '../training_controller.dart';
import 'widgets/card_esercizio_scrittura.dart';
import 'widgets/muscoli_della_scheda.dart';
import 'widgets/scelta_tipo_scheda.dart';

class PlanEditorScreen extends ConsumerStatefulWidget {
  const PlanEditorScreen({this.planId, this.tipo, super.key});

  /// `null` = scheda nuova.
  final int? planId;

  /// Quanti giorni avrà, deciso **prima** di entrare — 3b-D.2.
  ///
  /// ⚠️ `null` su una scheda che esiste già: il tipo lo dicono i suoi giorni.
  final TipoDiScheda? tipo;

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  final _nome = TextEditingController();
  final _note = TextEditingController();

  /// I giorni, ognuno con i suoi esercizi. Una scheda a giorno unico ne ha uno.
  ///
  /// 💡 **Anche il caso semplice è una lista di uno**, e non due strade
  /// diverse: la scheda a un giorno è la multi-day senza la barra sopra, ed è
  /// esattamente quello che ha chiesto il committente — *«IDENTICA a quella
  /// single day con una differenza»*.
  final _giorni = <List<EsercizioInScrittura>>[];

  int _giorno = 0;
  bool _pronto = false;
  bool _inCorso = false;
  String? _errore;

  bool get _piuGiorni =>
      widget.tipo == TipoDiScheda.piuGiorni || _giorni.length > 1;

  @override
  void initState() {
    super.initState();

    if (widget.planId == null) {
      _giorni.add([EsercizioInScrittura()]);
      _pronto = true;
    } else {
      _carica();
    }
  }

  Future<void> _carica() async {
    final scheda = await ref.read(planDetailProvider(widget.planId!).future);

    _nome.text = scheda.name;
    _note.text = scheda.notes ?? '';

    final grezza = await ref.read(archivioSaluteProvider).laScheda(
      widget.planId!,
    );

    /*
     * ⚠️ **Si rilegge il JSON grezzo e non `PlanExercise`.** Il modello
     * dell'app tiene la prescrizione gia' formattata e perde le righe: qui
     * serve il dato com'e' scritto, che e' l'unico posto in cui le serie
     * vivono per intero.
     */
    final busta = grezza == null
        ? const <String, dynamic>{}
        : (json.decode(grezza.scheda) as Map).cast<String, dynamic>();

    final giorni = busta['days'] as List?;

    setState(() {
      if (giorni != null && giorni.isNotEmpty) {
        for (final g in giorni) {
          final esercizi = ((g as Map)['exercises'] as List?) ?? const [];

          _giorni.add([
            for (final e in esercizi)
              EsercizioInScrittura.da((e as Map).cast<String, dynamic>()),
          ]);
        }
      } else {
        _giorni.add([
          for (final e in (busta['exercises'] as List?) ?? const [])
            EsercizioInScrittura.da((e as Map).cast<String, dynamic>()),
        ]);
      }

      for (final g in _giorni) {
        if (g.isEmpty) g.add(EsercizioInScrittura());
      }

      if (_giorni.isEmpty) _giorni.add([EsercizioInScrittura()]);

      _pronto = true;
    });
  }

  @override
  void dispose() {
    _nome.dispose();
    _note.dispose();

    for (final giorno in _giorni) {
      for (final e in giorno) {
        e.dispose();
      }
    }

    super.dispose();
  }

  Future<void> _salva() async {
    if (_nome.text.trim().isEmpty) {
      setState(() => _errore = 'Dai un nome alla scheda.');

      return;
    }

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    // Gli esercizi senza nome si scartano: l'editor ne tiene volentieri uno
    // vuoto in fondo, pronto da compilare, e non deve bloccare il salvataggio.
    List<Map<String, dynamic>> scritti(List<EsercizioInScrittura> giorno) => [
      for (final e in giorno)
        if (e.nome.text.trim().isNotEmpty) e.versoIlDato(),
    ];

    try {
      final azioni = ref.read(planActionsProvider);

      final nome = _nome.text.trim();
      final note = _note.text.trim().isEmpty ? null : _note.text.trim();

      if (widget.planId == null) {
        await azioni.create(
          name: nome,
          notes: note,
          exercises: scritti(_giorni.first),
          giorni: _piuGiorni
              ? [for (final g in _giorni) scritti(g)]
              : null,
        );
      } else {
        await azioni.update(
          id: widget.planId!,
          name: nome,
          notes: note,
          exercises: scritti(_giorni.first),
          giorni: _piuGiorni
              ? [for (final g in _giorni) scritti(g)]
              : null,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      setState(() {
        _errore = ApiClient.unwrapError(error).message;
        _inCorso = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_pronto) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tema = Theme.of(context);
    final esercizi = _giorni[_giorno];

    return Scaffold(
      appBar: IntestazioneApp(
        titolo: widget.planId == null ? 'Nuova scheda' : 'Modifica scheda',
      ),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          TextField(
            controller: _nome,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'es. Full body A',
            ),
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _note,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Note (facoltative)'),
          ),

          if (_piuGiorni) ...[
            const SizedBox(height: Gap.md),
            _BarraDeiGiorni(
              quanti: _giorni.length,
              scelto: _giorno,
              onScegli: (i) => setState(() => _giorno = i),
              onAggiungi: _giorni.length < giorniMassimi
                  ? () => setState(() {
                      _giorni.add([EsercizioInScrittura()]);
                      _giorno = _giorni.length - 1;
                    })
                  : null,
            ),
          ],

          const SizedBox(height: Gap.lg),

          for (var i = 0; i < esercizi.length; i++)
            CardEsercizioScrittura(
              key: ObjectKey(esercizi[i]),
              esercizio: esercizi[i],
              numero: i + 1,
              onCambio: () => setState(() {}),
              onRimuovi: () => setState(() {
                esercizi.removeAt(i).dispose();

                // ⛔ Mai zero: una scheda senza righe non si puo' scrivere.
                if (esercizi.isEmpty) esercizi.add(EsercizioInScrittura());
              }),
            ),

          OutlinedButton.icon(
            onPressed: () =>
                setState(() => esercizi.add(EsercizioInScrittura())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Aggiungi esercizio'),
          ),

          const SizedBox(height: Gap.lg),

          /*
           * ══ 🧍 LA FIGURA, MENTRE SI SCRIVE — 3b-D.6 ═══════════════════════
           *
           * 📌 *«In fondo alla scheda, ci deve essere la card con l'uomo e i
           * muscoli allenati e il grafico a stella (le stesse dello storico e
           * dell'esercizio individuale)»*.
           *
           * 💡 «Le stesse» alla lettera: **gli stessi widget**, non una copia.
           * Due figure che divergono sono peggio di una figura sola.
           */
          MuscoliDellaScheda(giorni: _giorni),

          if (_errore != null) ...[
            const SizedBox(height: Gap.md),
            Text(_errore!, style: TextStyle(color: tema.colorScheme.error)),
          ],

          const SizedBox(height: Gap.lg),
          FilledButton(
            onPressed: _inCorso ? null : _salva,
            child: _inCorso
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salva scheda'),
          ),
          const SizedBox(height: Gap.xl),
        ],
      ),
    );
  }
}

/// 📌 *«con la possibilità di aggiungere giorni max 7»*.
const giorniMassimi = 7;

class _BarraDeiGiorni extends StatelessWidget {
  const _BarraDeiGiorni({
    required this.quanti,
    required this.scelto,
    required this.onScegli,
    required this.onAggiungi,
  });

  final int quanti;
  final int scelto;
  final ValueChanged<int> onScegli;
  final VoidCallback? onAggiungi;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < quanti; i++)
            Padding(
              padding: const EdgeInsets.only(right: Gap.xs),
              child: ChoiceChip(
                label: Text('Giorno ${i + 1}'),
                selected: i == scelto,
                onSelected: (_) => onScegli(i),
              ),
            ),

          // ⚠️ Sparisce al settimo invece di restare spento: un pulsante grigio
          // fa chiedere perche', e la risposta non sta a schermo.
          if (onAggiungi != null)
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Giorno'),
              onPressed: onAggiungi,
            ),
        ],
      ),
    );
  }
}

/// La card con la figura e la stella, sui muscoli di quello che si sta
/// scrivendo — 3b-D.6.
class MuscoliDellaScheda extends ConsumerWidget {
  const MuscoliDellaScheda({required this.giorni, super.key});

  final List<List<EsercizioInScrittura>> giorni;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo =
        ref.watch(catalogoEserciziProvider).valueOrNull ?? CatalogoEsercizi.vuoto;

    final pesi = <GruppoMuscolare, double>{};

    for (final giorno in giorni) {
      for (final e in giorno) {
        if (e.nome.text.trim().isEmpty) continue;

        /*
         * 💡 Prima per id — l'identita' vera, quella che arriva scegliendo
         * dall'elenco — e per nome solo come ripiego. E' la stessa precedenza
         * di `pesiDellaScheda`.
         */
        final dal =
            catalogo.perId(e.exerciseId) ??
            catalogo.perNome(e.nome.text.trim());

        final primario = dal?.primario ?? e.muscoli?.primario;
        final secondari = dal?.secondari ?? e.muscoli?.secondari ?? const [];

        if (primario != null) {
          pesi[primario] = (pesi[primario] ?? 0) + 1;
        }

        for (final s in secondari) {
          pesi[s] = (pesi[s] ?? 0) + 0.5;
        }
      }
    }

    /*
     * ⚠️ **Muta finche' non si sa niente.** Una figura tutta spenta sotto una
     * scheda vuota sembra un difetto; qui non c'e' proprio finche' non c'e'
     * qualcosa da dire.
     */
    if (pesi.isEmpty) return const SizedBox.shrink();

    final massimo = pesi.values.reduce((a, b) => a > b ? a : b);

    final intensita = {
      for (final voce in pesi.entries) voce.key: voce.value / massimo,
    };

    return MuscoliInCard(intensita: intensita);
  }
}
