/// Un esercizio durante l'allenamento — 3b-E.10, 26/08/2026.
///
/// ══ 📌 LA CORREZIONE, DOPO AVERLA VISTA ═══════════════════════════════════
///
/// *«non c'è bisogno che tutta l'interfaccia sia uguale all'editor, in questo
/// caso: io direi che cliccando sulla matita diventa possibile modificare nome,
/// pesi, note, foto e il selettore tra peso nessuno e iso. Altrimenti deve
/// essere solo la lista degli esercizi, con il nome scritto senza campo di
/// input»*.
///
/// ══ 🚨 PERCHE' AVEVA RAGIONE ══════════════════════════════════════════════
///
/// ⛔ In 3b-E la card dell'allenamento era **letteralmente** quella dell'editor:
/// sei campi di testo per esercizio, il selettore del carico, il riquadro della
/// foto. Rispondeva alla lettera a *«mostrare gli esercizi come quella
/// dell'editor»*, e a schermo era una schermata da scrivania.
///
/// 🚨 In palestra quella schermata si **legge** e si **spunta**: si guarda da un
/// metro, appoggiata, fra due serie. Un campo di testo lì è un bersaglio che si
/// apre da solo — la tastiera che sale copre metà lista, e chi voleva premere la
/// spunta si ritrova a scrivere dentro il nome dell'esercizio.
///
/// 💡 Quindi due stati, e il confine è **la matita**:
///
/// | | Chiusa | Aperta |
/// |---|---|---|
/// | il nome | testo | campo con l'elenco del catalogo |
/// | le serie | una riga letta, e la spunta | i tre campi, la x, lo slide |
/// | carico, foto, note, muscoli | non ci sono | ci sono tutti |
/// | togliere l'esercizio | ⛔ no | il cestino |
/// | spostarlo | la maniglia | la maniglia |
///
/// ⚠️ **La spunta c'è in tutti e due**: è l'unica cosa che si fa sempre, e
/// nasconderla dietro un tocco vorrebbe dire un tocco in più per ogni serie di
/// ogni allenamento.
///
/// ⛔ **Togliere un esercizio si fa solo da aperta**, ed è voluto: è l'unico
/// gesto distruttivo della schermata, e a card chiusa il cestino starebbe a due
/// centimetri dalle spunte. 💡 C'è comunque l'Annulla (3b-E.7).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/allenamento_in_corso.dart';
import '../../data/catalogo_esercizi.dart';
import '../../data/scheda_in_scrittura.dart';
import '../../data/serie_prevista.dart';
import 'card_esercizio_scrittura.dart';
import 'esercizio_della_scheda.dart';
import 'righe_delle_serie.dart';
import 'spunta_della_serie.dart';

class CardEsercizioAllenamento extends ConsumerStatefulWidget {
  const CardEsercizioAllenamento({
    required this.esercizio,
    required this.numero,
    required this.posizione,
    required this.onSpunta,
    required this.onCambio,
    required this.onRimuovi,
    super.key,
  });

  final EsercizioInAllenamento esercizio;
  final int numero;
  final int posizione;

  /// L'indice della riga da registrare.
  final void Function(int riga) onSpunta;

  final VoidCallback onCambio;
  final VoidCallback onRimuovi;

  @override
  ConsumerState<CardEsercizioAllenamento> createState() =>
      _CardEsercizioAllenamentoState();
}

class _CardEsercizioAllenamentoState
    extends ConsumerState<CardEsercizioAllenamento> {
  /// ⚠️ **Un esercizio senza nome nasce aperto.** È quello appena aggiunto: a
  /// card chiusa mostrerebbe una riga vuota e nessun modo evidente di
  /// riempirla, e chi l'ha appena creato dovrebbe cercare la matita per fare la
  /// cosa che stava già facendo.
  late bool _aperto = widget.esercizio.nome.text.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_aperto) {
      return CardEsercizioScrittura(
        esercizio: widget.esercizio,
        numero: widget.numero,
        posizione: widget.posizione,

        // ⚠️ Da aperta l'etichetta di casa («Esercizio 3») serve ancora: il
        // nome è dentro un campo, e senza quella riga non si sa a che punto
        // della scheda si è.
        etichetta: _etichetta == null
            ? null
            : 'Esercizio ${widget.numero} · $_etichetta',
        codaDellaRiga: _spunta,
        azioni: [
          IconButton(
            onPressed: () => setState(() => _aperto = false),
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Fatto',
          ),
        ],
        onCambio: widget.onCambio,
        onRimuovi: widget.onRimuovi,
      );
    }

    return _CardChiusa(
      esercizio: widget.esercizio,
      etichetta: _etichetta,
      posizione: widget.posizione,
      spunta: _spunta,
      onCambio: widget.onCambio,
      onApri: () => setState(() => _aperto = true),
    );
  }

  Widget _spunta(int riga) => SpuntaDellaSerie(
    fatta: widget.esercizio.serieFatte[riga].fatta,
    onTocco: () => widget.onSpunta(riga),
  );

  /// «2 di 4», e «fatto» quando è finito.
  ///
  /// ⚠️ Su un esercizio intatto non compare: uno «0 di 4» sarebbe rumore.
  String? get _etichetta {
    final e = widget.esercizio;

    if (e.quanteFatte == 0) return null;

    return e.tuttoFatto ? 'fatto' : '${e.quanteFatte} di ${e.righe.length}';
  }
}

/// La card a riposo: si legge e si spunta, e basta.
class _CardChiusa extends ConsumerWidget {
  const _CardChiusa({
    required this.esercizio,
    required this.etichetta,
    required this.posizione,
    required this.spunta,
    required this.onCambio,
    required this.onApri,
  });

  final EsercizioInAllenamento esercizio;
  final String? etichetta;
  final int posizione;
  final Widget Function(int riga) spunta;
  final VoidCallback onCambio;
  final VoidCallback onApri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    /*
     * 💡 **L'illustrazione si ricava dal catalogo, non si conserva.** L'id
     * dell'esercizio ce l'abbiamo; copiarsi l'URL dentro la scheda sarebbe una
     * seconda copia che invecchia — e che si porterebbe dietro l'immagine di un
     * esercizio anche dopo averlo rinominato.
     */
    final dalCatalogo = ref
        .watch(catalogoEserciziProvider)
        .valueOrNull
        ?.perId(esercizio.exerciseId);

    final nome = esercizio.nome.text.trim();
    final note = esercizio.note.text.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.md),
      child: Padding(
        padding: const EdgeInsets.all(Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                /*
                 * ⚠️ **Il credito arriva anche qui, ma non si scrive.** Serve
                 * a tingere: senza, il disegno bianco su fondo chiaro non si
                 * vedrebbe proprio. 🚨 La riga «Illustrazione: …» sta solo
                 * nella pagina della scheda — *«non durante l'allenamento»* —
                 * e infatti questo widget non la disegna.
                 */
                FotoDellEsercizio(
                  immagine: esercizio.immagine,
                  url: dalCatalogo?.immagine,
                  etichetta: nome,
                  lato: 48,
                  credito: dalCatalogo?.credito,
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // ⚠️ Un esercizio senza nome a card chiusa non capita
                        // (nasce aperto), ma una card muta sarebbe peggio di
                        // una che dice cosa manca.
                        nome.isEmpty ? 'Esercizio senza nome' : nome,
                        style: tema.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (etichetta case final quante?)
                        Text(
                          quante,
                          style: tema.textTheme.labelSmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),

                /*
                 * 📌 *«cliccando sulla matita diventa possibile modificare nome,
                 * pesi, note, foto e il selettore tra peso nessuno e iso»*.
                 */
                IconButton(
                  onPressed: onApri,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Modifica questo esercizio',
                ),

                // ↕️ La maniglia resta anche da chiusa: in sala si sposta un
                // esercizio perché la macchina è occupata, non perché lo si sta
                // modificando.
                ReorderableDragStartListener(
                  index: posizione,
                  child: const Padding(
                    padding: EdgeInsets.only(left: Gap.xs),
                    child: Icon(Icons.drag_handle_rounded),
                  ),
                ),
              ],
            ),

            const SizedBox(height: Gap.xs),

            for (var i = 0; i < esercizio.righe.length; i++)
              _RigaDaSpuntare(
                numero: i + 1,
                riga: esercizio.righe[i],
                carico: esercizio.carico,
                fatta: esercizio.serieFatte[i].fatta,
                spunta: spunta(i),
                onCambio: () {
                  esercizio.toccata(i);
                  onCambio();
                },
              ),

            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs, left: Gap.xs),
                child: Text(
                  note,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Una serie a card chiusa: si legge, si corregge, si spunta.
///
/// ══ 📌 LA SECONDA CORREZIONE ══════════════════════════════════════════════
///
/// *«ripetizioni e peso devono poter essere modificate anche senza la matita»*.
///
/// 🚨 **È il gesto più frequente dell'allenamento**, e va capito bene: si arriva
/// al bilanciere, si vede che oggi 45 sono troppi, si mettono 42,5 e si spinge.
/// ⛔ Mandarlo dietro la matita vorrebbe dire due tocchi in più per la cosa che
/// si fa **a ogni serie**, e quella schermata si usa con le mani sudate.
///
/// 💡 Il **recupero** invece resta letto: è una prescrizione che si corregge una
/// volta ogni tanto, e sta bene sotto la matita. ⚠️ Ed è anche quello che tiene
/// la riga larga abbastanza per due campi a 328 px.
class _RigaDaSpuntare extends StatelessWidget {
  const _RigaDaSpuntare({
    required this.numero,
    required this.riga,
    required this.carico,
    required this.fatta,
    required this.spunta,
    required this.onCambio,
  });

  final int numero;
  final SerieInScrittura riga;
  final CaricoDellEsercizio carico;
  final bool fatta;
  final Widget spunta;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final recupero = riga.recupero.text.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$numero',
              style: tema.textTheme.labelMedium?.copyWith(
                /*
                 * 💡 **Una serie fatta si sbiadisce.** Scorrendo la lista da un
                 * metro, quello che serve sapere è dove si è arrivati: il colore
                 * lo dice prima di leggere i numeri. ⚠️ Sbiadita e non barrata —
                 * una riga barrata dice «annullata», non «fatta».
                 */
                color: fatta
                    ? tema.colorScheme.primary
                    : tema.colorScheme.onSurfaceVariant,
                fontWeight: fatta ? FontWeight.w700 : null,
              ),
            ),
          ),

          Expanded(
            child: CampoDellaSerie(
              controller: riga.ripetizioni,
              etichetta: 'Rip.',
              onCambio: onCambio,
            ),
          ),

          // ⚠️ Con `niente` la colonna sparisce, come nell'editor: un campo
          // grigio che non si può toccare fa chiedere perché.
          if (carico != CaricoDellEsercizio.niente) ...[
            const SizedBox(width: Gap.xs),
            Expanded(
              child: CampoDellaSerie(
                controller: riga.carico,
                etichetta: carico == CaricoDellEsercizio.iso ? 'Sec.' : 'Kg',
                onCambio: onCambio,
              ),
            ),
          ],

          /*
           * ⏱️ Il recupero **si legge e non si tocca**: qui serve a sapere
           * quanto durerà la pausa che sta per partire. ⚠️ Niente riquadro:
           * un campo spento in mezzo a due accesi sembrerebbe rotto.
           */
          SizedBox(
            width: 54,
            child: Text(
              recupero.isEmpty ? '' : '${recupero}s',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          spunta,
        ],
      ),
    );
  }
}
