/// Il campo del nome di un esercizio, con i suggerimenti — 3b-R, 28/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«quando inizio a scrivere il nome dell'esercizio nel builder delle schede e
/// nel player (se ne aggiungo uno dal player) si deve vedere l'immagine come
/// succede per gli alimenti»*.
///
/// ══ 🚨 SERVE A SCEGLIERE QUELLO GIÀ IN CATALOGO ═══════════════════════════
///
/// ⛔ Senza, chi scrive «panca piana con i manubri» crea un esercizio nuovo che
/// dice la stessa cosa di uno che c'è già. Il matcher sul server ne recupera
/// una parte, ma non tutti: e ogni doppione è **un progresso diviso in due
/// righe** — che è il danno per cui è nata l'intera fase 3b-Q.
///
/// 💡 **L'immagine non è decorazione**: è la prova che quello scritto è
/// davvero l'esercizio che si aveva in mente. «Croci ai cavi» e «Croci ai cavi
/// alti» si distinguono meglio da due disegni che da due righe di testo.
///
/// ── ⚠️ Perché è un campo e non un `Autocomplete` ──────────────────────────
///
/// 🚨 Il nome **libero deve restare libero**: si può scrivere un esercizio che
/// il catalogo non ha, e succede di continuo. ⛔ `Autocomplete` di Material
/// spinge verso «scegli una voce», e un campo che rifiuta quello che scrivi in
/// una scheda è un campo che fa scrivere il nome nelle note.
///
/// 💡 Qui il suggerimento è **un aiuto**: se serve lo si tocca, altrimenti si
/// continua a scrivere e non succede niente.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/miniatura.dart';
import '../../data/catalogo_esercizi.dart';

class CampoEsercizio extends ConsumerStatefulWidget {
  const CampoEsercizio({
    required this.iniziale,
    required this.onCambiato,
    this.onScelto,
    this.etichetta = 'Esercizio',
    this.autofocus = false,
    super.key,
  });

  final String iniziale;

  /// Chiamata a **ogni** battuta: il nome libero resta libero.
  final ValueChanged<String> onCambiato;

  /// Chiamata solo quando si tocca un suggerimento.
  ///
  /// 💡 Serve a chi vuole prendersi anche i muscoli, che il catalogo conosce
  /// già: senza, il compositore li richiederebbe per un esercizio che il server
  /// sa descrivere da solo.
  final ValueChanged<EsercizioDelCatalogo>? onScelto;

  final String etichetta;
  final bool autofocus;

  @override
  ConsumerState<CampoEsercizio> createState() => _CampoEsercizioState();
}

class _CampoEsercizioState extends ConsumerState<CampoEsercizio> {
  late final TextEditingController _campo = TextEditingController(
    text: widget.iniziale,
  );
  final _fuoco = FocusNode();

  /// ⚠️ Chiuso a mano dopo una scelta: senza, il suggerimento resterebbe
  /// aperto sopra quello che si è appena scelto.
  bool _mostra = false;

  /// Quanti suggerimenti al massimo.
  ///
  /// 💡 Cinque perché la lista sta **sopra la tastiera**: più lunga e i primi
  /// finiscono fuori schermo, cioè si vedono solo i peggiori.
  static const _quanti = 5;

  @override
  void initState() {
    super.initState();
    _fuoco.addListener(() {
      if (!_fuoco.hasFocus) setState(() => _mostra = false);
    });
  }

  @override
  void dispose() {
    _campo.dispose();
    _fuoco.dispose();
    super.dispose();
  }

  List<EsercizioDelCatalogo> _suggeriti() {
    final scritto = CatalogoEsercizi.normalizza(_campo.text);

    // ⛔ Sotto i due caratteri si suggerirebbe mezzo catalogo.
    if (!_mostra || scritto.length < 2) return const [];

    final catalogo = ref.watch(catalogoEserciziProvider).valueOrNull;

    if (catalogo == null) return const [];

    final trovati = catalogo.tutti
        .where((e) => CatalogoEsercizi.normalizza(e.nome).contains(scritto))
        .toList();

    /*
     * 💡 **Prima quelli che COMINCIANO con quello che si sta scrivendo.**
     * Cercando «panca», «Panca piana» deve venire prima di «Dips su panca»:
     * chi scrive l'inizio di un nome sta pensando a quel nome.
     */
    trovati.sort((a, b) {
      final ai = CatalogoEsercizi.normalizza(a.nome).startsWith(scritto) ? 0 : 1;
      final bi = CatalogoEsercizi.normalizza(b.nome).startsWith(scritto) ? 0 : 1;

      return ai != bi ? ai - bi : a.nome.length.compareTo(b.nome.length);
    });

    return trovati.take(_quanti).toList();
  }

  void _scegli(EsercizioDelCatalogo e) {
    _campo.text = e.nome;
    widget.onCambiato(e.nome);
    widget.onScelto?.call(e);

    setState(() => _mostra = false);
    _fuoco.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final suggeriti = _suggeriti();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _campo,
          focusNode: _fuoco,
          autofocus: widget.autofocus,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: widget.etichetta,
            isDense: true,
          ),
          onChanged: (v) {
            widget.onCambiato(v);
            setState(() => _mostra = true);
          },
        ),

        if (suggeriti.isNotEmpty) _Suggerimenti(righe: suggeriti, onScelto: _scegli),
      ],
    );
  }
}

class _Suggerimenti extends StatelessWidget {
  const _Suggerimenti({required this.righe, required this.onScelto});

  final List<EsercizioDelCatalogo> righe;
  final ValueChanged<EsercizioDelCatalogo> onScelto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: Gap.xs),
      decoration: BoxDecoration(
        border: Border.all(color: tema.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(Gap.radiusSm),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: righe.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final e = righe[i];
          final muscoli = e.primario?.etichetta;

          return ListTile(
            dense: true,
            leading: Miniatura(
              url: e.immagine,
              etichetta: e.nome,
              lato: 40,
              // ⚠️ Stessa regola di tutto il resto: si tinge solo quando è un
              // disegno nostro, cioè quando c'è un credito da rendere.
              tinta: e.credito == null
                  ? null
                  : tema.colorScheme.onSurfaceVariant,
            ),
            title: Text(e.nome, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: muscoli == null ? null : Text(muscoli),
            onTap: () => onScelto(e),
          );
        },
      ),
    );
  }
}
