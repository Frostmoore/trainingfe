/// Chiedere che muscoli allena un esercizio — 3b-A.3.4, 23/08/2026.
///
/// ══ 🚨 SI CHIEDE SOLO QUANDO SERVE ═════════════════════════════════════════
///
/// 📌 *«Tutti gli esercizi devono indicare il muscolo o il gruppo muscolare che
/// allenano (anche più di uno). Ovviamente questo va fatto anche dove vengono
/// creati gli esercizi»*.
///
/// ⛔ Chiederlo per **ogni** esercizio sarebbe la lettura sbagliata della
/// richiesta: dei 121 in catalogo il server i muscoli li sa già, e non li
/// sovrascrive con quello che scrive un iscritto. Mettere una domanda sotto
/// «Panca piana» vorrebbe dire far compilare un campo che non cambia niente —
/// e quando una domanda non serve, si smette di leggerla anche quando serve.
///
/// 💡 Quindi: nome riconosciuto → si **mostra** quello che il catalogo sa; nome
/// nuovo → si **chiede**, perché è l'unico momento in cui la risposta entra
/// davvero nella libreria.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/catalogo_esercizi.dart';
import '../../data/gruppo_muscolare.dart';

/// Come si legge un elenco di muscoli: «Petto · tricipiti, spalle».
String descriviMuscoli(MuscoliScelti m) {
  if (m.primario == null && m.secondari.isEmpty) return '';

  final aiuto = m.secondari.map((g) => g.etichetta.toLowerCase()).join(', ');

  if (m.primario == null) return aiuto;

  return aiuto.isEmpty
      ? m.primario!.etichetta
      : '${m.primario!.etichetta} · $aiuto';
}

/// Apre la scelta e torna quello che è stato deciso, o `null` se si annulla.
Future<MuscoliScelti?> chiediIMuscoli(
  BuildContext context, {
  required String nomeEsercizio,
  MuscoliScelti iniziali = const (
    primario: null,
    secondari: <GruppoMuscolare>[],
  ),
}) => showModalBottomSheet<MuscoliScelti>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      _FoglioMuscoli(nomeEsercizio: nomeEsercizio, iniziali: iniziali),
);

class _FoglioMuscoli extends StatefulWidget {
  const _FoglioMuscoli({required this.nomeEsercizio, required this.iniziali});

  final String nomeEsercizio;
  final MuscoliScelti iniziali;

  @override
  State<_FoglioMuscoli> createState() => _FoglioMuscoliState();
}

class _FoglioMuscoliState extends State<_FoglioMuscoli> {
  late GruppoMuscolare? _primario = widget.iniziali.primario;
  late final Set<GruppoMuscolare> _secondari = {...widget.iniziali.secondari};

  /// Al massimo sei, come il server (`max:6` in `WorkoutPlanRequest`).
  ///
  /// ⚠️ Il limite sta in tutti e due i posti di proposito: qui perché una
  /// scelta che il server rifiuterà non deve nemmeno essere possibile, e lì
  /// perché l'app non è l'unico modo per scrivere.
  static const _massimoSecondari = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.nomeEsercizio.trim().isEmpty
                    ? 'Che muscoli allena?'
                    : 'Che muscoli allena «${widget.nomeEsercizio.trim()}»?',
                style: theme.textTheme.titleMedium,
              ),

              const SizedBox(height: Gap.xs),

              Text(
                'Serve a colorare la figura del corpo e il grafico dei muscoli. '
                'Questo esercizio non è in libreria, quindi lo sai solo tu.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: Gap.md),

              Text(
                'Quello che fa il lavoro',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: Gap.xs),

              Wrap(
                spacing: Gap.xs,
                runSpacing: Gap.xs,
                children: [
                  for (final g in GruppoMuscolare.values)
                    ChoiceChip(
                      label: Text(g.etichetta),
                      selected: _primario == g,
                      onSelected: (scelto) => setState(() {
                        _primario = scelto ? g : null;

                        // 💡 Non può essere anche secondario di sé stesso: la
                        // riga sarebbe contraddittoria e il peso lo direbbe.
                        _secondari.remove(g);
                      }),
                    ),
                ],
              ),

              const SizedBox(height: Gap.md),

              Text('Quelli che aiutano', style: theme.textTheme.labelLarge),
              const SizedBox(height: Gap.xs),

              Text(
                'Lascia vuoto se l\'esercizio isola davvero: è una risposta, '
                'non un campo saltato.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: Gap.xs),

              Wrap(
                spacing: Gap.xs,
                runSpacing: Gap.xs,
                children: [
                  for (final g in GruppoMuscolare.values)
                    if (g != _primario)
                      FilterChip(
                        label: Text(g.etichetta),
                        selected: _secondari.contains(g),
                        onSelected: (scelto) => setState(() {
                          if (!scelto) {
                            _secondari.remove(g);

                            return;
                          }

                          if (_secondari.length < _massimoSecondari) {
                            _secondari.add(g);
                          }
                        }),
                      ),
                ],
              ),

              const SizedBox(height: Gap.lg),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop((
                    primario: _primario,

                    // ⚠️ L'ordine dei chip e non quello dei tocchi: due volte
                    // lo stesso esercizio deve dare la stessa riga, o due
                    // scritture identiche sembrano diverse.
                    secondari: GruppoMuscolare.values
                        .where(_secondari.contains)
                        .toList(growable: false),
                  )),
                  child: const Text('Va bene'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// I muscoli di un esercizio: mostrati se si sanno, chiesti se non si sanno.
///
/// ══ 🚨 LA DOMANDA COMPARE SOLO DOVE CAMBIA QUALCOSA — 3b-A.3.4 ═══════════
///
/// 📌 *«Tutti gli esercizi devono indicare il muscolo o il gruppo muscolare che
/// allenano (anche più di uno)»*.
///
/// ⛔ Metterla sotto ogni riga sarebbe la lettura sbagliata: per i 121 esercizi
/// in libreria il server i muscoli li **sa già**, e non li sovrascrive con
/// quello che scrive un iscritto (`ExerciseMatcher::completa()`). Una domanda
/// la cui risposta viene buttata via è peggio di nessuna domanda — insegna a
/// non leggerle.
///
/// 💡 Quindi tre casi: nome vuoto → niente; nome riconosciuto → si **mostra**
/// quello che la libreria sa; nome nuovo → si **chiede**, perché è l'unico
/// momento in cui la risposta entra davvero nel catalogo.
///
/// ⚠️ Il riconoscimento qui è un **indizio**, non la riconciliazione vera:
/// quella la fa il server, che conosce sinonimi e corrispondenze parziali. Se
/// questo sbaglia, sbaglia chiedendo una cosa in più.
class RigaMuscoli extends ConsumerWidget {
  const RigaMuscoli({
    required this.nome,
    required this.muscoli,
    required this.onScelti,
    super.key,
  });

  /// Il nome scritto adesso nel campo, non quello salvato.
  final String nome;

  /// Quello che e' gia' stato scelto per questo esercizio, se qualcosa.
  final MuscoliScelti? muscoli;

  final ValueChanged<MuscoliScelti> onScelti;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (nome.trim().isEmpty) return const SizedBox.shrink();

    /*
     * ⚠️ **Il catalogo non blocca niente.** Se non e' ancora arrivato — prima
     * chiamata, telefono senza rete — si comporta come se l'esercizio fosse
     * nuovo: chiede. 🚨 Il contrario (non chiedere finche' non si sa) vorrebbe
     * dire che con la rete lenta la domanda non compare **mai**, ed e' il tipo
     * di guasto che nessuno collega alla causa.
     */
    final catalogo =
        ref.watch(catalogoEserciziProvider).valueOrNull ??
        CatalogoEsercizi.vuoto;

    final noto = catalogo.perNome(nome);

    if (noto != null) {
      final descrizione = descriviMuscoli((
        primario: noto.primario,
        secondari: noto.secondari,
      ));

      if (descrizione.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(top: Gap.xs),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Gap.xs),
            Expanded(
              child: Text(
                descrizione,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final scelti = muscoli;
    final descrizione = scelti == null ? '' : descriviMuscoli(scelti);

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () async {
          final risposta = await chiediIMuscoli(
            context,
            nomeEsercizio: nome,
            iniziali:
                scelti ??
                const (primario: null, secondari: <GruppoMuscolare>[]),
          );

          if (risposta == null) return;

          onScelti(risposta);
        },
        icon: Icon(
          scelti == null ? Icons.help_outline : Icons.edit_outlined,
          size: 16,
        ),
        label: Text(
          scelti == null
              ? 'Che muscoli allena?'
              : descrizione.isEmpty
              ? 'Nessun muscolo indicato'
              : descrizione,
          style: theme.textTheme.bodySmall,
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
