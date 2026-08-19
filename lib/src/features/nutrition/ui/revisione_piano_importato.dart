import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/media/archivio_foto.dart';
import '../../../core/media/tipo_foto.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/avvertenza_nutrizionale.dart';
import '../../health/health_controller.dart';
import '../data/importazione_piano.dart';

/// La revisione riga per riga di un piano trascritto — N20.3.
///
/// ── 🚨 È la schermata più importante di tutto N20 ─────────────────────────
///
/// Il rischio dell'importazione non è che l'AI **fallisca**: un fallimento si
/// vede e si rifà. È che riesca **a metà**. «200 g» letti «20 g» non danno
/// nessun errore: producono un piano plausibile e sbagliato, che qualcuno
/// seguirà per settimane credendolo fedele all'originale.
///
/// ⚠️ **Quindi questa schermata non è una conferma, è un lavoro.** Tutto qui
/// dentro è progettato perché confrontare sia più facile che fidarsi:
///
///   * si dice **prima** quante righe ci sono («34 righe da controllare»);
///   * i **dubbi dichiarati dal modello** stanno in cima, non sepolti;
///   * l'**originale si apre da ogni schermata**, in un tocco;
///   * ogni valore è **modificabile**, e correggerlo è la via normale;
///   * il pulsante finale dice *«Ho controllato tutto»*, non *«Conferma»*.
///
/// 💡 L'ultima riga non è cosmetica: chiedere una dichiarazione invece di un
/// assenso costringe a decidere, e chi non ha controllato se ne accorge nel
/// momento in cui la legge.
class RevisionePianoImportato extends ConsumerStatefulWidget {
  const RevisionePianoImportato({required this.importazione, super.key});

  final ImportazionePiano importazione;

  @override
  ConsumerState<RevisionePianoImportato> createState() => _RevisionePianoImportatoState();
}

class _RevisionePianoImportatoState extends ConsumerState<RevisionePianoImportato> {
  late final List<_Giorno> _giorni;
  late final TextEditingController _nome;

  bool _inCorso = false;
  String? _errore;

  /// Il PDF, una volta salvato sul telefono.
  ///
  /// 🚨 **Si scarica una volta e resta**, dentro `Documents/foto/piani`, che è
  /// nel backup. L'originale deve poter essere riaperto anche fra sei mesi:
  /// sul server la riga scade dopo sette giorni, e senza copia locale non
  /// resterebbe niente con cui confrontare i numeri che si stanno seguendo.
  String? _pdfLocale;

  @override
  void initState() {
    super.initState();

    _nome = TextEditingController(text: widget.importazione.nome);
    _giorni = _leggi(widget.importazione.bozza);
  }

  @override
  void dispose() {
    _nome.dispose();

    for (final giorno in _giorni) {
      giorno.smonta();
    }

    super.dispose();
  }

  static List<_Giorno> _leggi(Map<String, dynamic>? bozza) {
    return ((bozza?['giorni'] as List?) ?? const [])
        .whereType<Map>()
        .map((g) => _Giorno.da(g.cast<String, dynamic>()))
        .toList();
  }

  int get _righe =>
      _giorni.fold(0, (t, g) => t + g.pasti.fold(0, (p, m) => p + m.alimenti.length));

  @override
  Widget build(BuildContext context) {
    final dubbi = widget.importazione.dubbi;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Controlla il piano'),
        actions: [
          IconButton(
            tooltip: 'Apri il PDF originale',
            onPressed: _apriOriginale,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          _Intestazione(righe: _righe, nomeFile: widget.importazione.nomeFile),
          const SizedBox(height: Gap.md),

          if (dubbi.isNotEmpty) ...[
            _Dubbi(dubbi: dubbi),
            const SizedBox(height: Gap.md),
          ],

          TextField(
            controller: _nome,
            decoration: const InputDecoration(
              labelText: 'Nome del piano',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: Gap.md),

          for (final giorno in _giorni) ...[
            _GiornoCard(giorno: giorno, apriOriginale: _apriOriginale),
            const SizedBox(height: Gap.md),
          ],

          if (_errore != null) ...[
            Text(_errore!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: Gap.sm),
          ],

          const SizedBox(height: Gap.sm),
          const AvvertenzaNutrizionale(),
          const SizedBox(height: Gap.md),

          FilledButton.icon(
            onPressed: _inCorso ? null : _confermo,
            icon: _inCorso
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.checklist),
            label: const Text('Ho controllato tutte le righe'),
          ),
          const SizedBox(height: Gap.sm),

          TextButton(
            onPressed: _inCorso ? null : _scarto,
            child: const Text('Scarta questa importazione'),
          ),
        ],
      ),
    );
  }

  /// Apre il PDF originale col lettore del telefono — N20.4.
  ///
  /// 🚨 **Prima si salva in `Documents/foto/piani`, poi si apre.** Aprirlo da
  /// una cartella temporanea vorrebbe dire che domani non c'è più: la cache è
  /// esclusa dal backup **per costruzione**, ed è esattamente ciò che rende
  /// affidabili le altre cartelle.
  Future<void> _apriOriginale() async {
    try {
      final relativo = _pdfLocale ??= await _scaricaOriginale();
      final file = await const ArchivioFoto().fileDi(relativo);

      await OpenFilex.open(file.path);
    } on Object catch (e) {
      if (!mounted) return;

      setState(() => _errore = 'Non riesco ad aprire l\'originale: $e');
    }
  }

  Future<String> _scaricaOriginale() async {
    final byte = await ref
        .read(importazioniPianiProvider)
        .pdf(widget.importazione.id);

    return const ArchivioFoto().salva(tipo: TipoFoto.piani, byte: byte);
  }

  /// Salva il piano sul telefono e chiude l'importazione sul server.
  ///
  /// ── 🚨 L'ordine conta ──────────────────────────────────────────────────
  ///
  /// Prima si scarica l'originale, poi si scrive il piano in archivio, e
  /// **solo alla fine** si dice al server di buttare tutto. Nell'ordine
  /// inverso, un guasto a metà lascerebbe la persona senza piano e senza
  /// originale, con la riga sul server già cancellata: niente da cui
  /// ricominciare.
  ///
  /// 💡 Se la chiusura sul server fallisce non è grave: la riga scade da sola
  /// dopo sette giorni. Il piano è già al sicuro sul telefono.
  Future<void> _confermo() async {
    if (!await _confermato()) return;

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      _pdfLocale ??= await _scaricaOriginale();

      await ref.read(archivioSaluteProvider).salvaPianoImportato(
        importazioneId: widget.importazione.id,
        nome: _nome.text.trim().isEmpty ? 'Piano importato' : _nome.text.trim(),
        piano: json.encode(_perLArchivio()),
        pdfOriginale: _pdfLocale,
      );

      try {
        await ref.read(importazioniPianiProvider).chiudi(widget.importazione.id);
      } on Object {
        // Vedi il dartdoc: la riga scade da sola, il piano e' gia' al sicuro.
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;

      setState(() {
        _errore = 'Non sono riuscito a salvare il piano: $e';
        _inCorso = false;
      });
    }
  }

  /// L'ultima domanda, che è una dichiarazione e non un assenso.
  ///
  /// ⚠️ *«Confermi?»* si tocca senza leggere. *«Ho confrontato tutte le righe
  /// con l'originale»* costringe a decidere se è vero — e chi non l'ha fatto se
  /// ne accorge proprio lì.
  Future<bool> _confermato() async {
    final risposta = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hai confrontato tutto?'),
        content: Text(
          'Stai per salvare questo piano come tuo. Le $_righe righe qui sopra '
          'le ha ricopiate un modello dal tuo PDF: un numero letto male non dà '
          'nessun errore, sembra solo un valore come gli altri.\n\n'
          'Confermando dichiari di aver confrontato le righe con l\'originale.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Torno a controllare'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Le ho confrontate'),
          ),
        ],
      ),
    );

    return risposta ?? false;
  }

  Future<void> _scarto() async {
    setState(() => _inCorso = true);

    try {
      await ref.read(importazioniPianiProvider).chiudi(widget.importazione.id);
    } on Object {
      // Scade da sola comunque: non vale la pena bloccare qui chi ha gia'
      // deciso di buttarla.
    }

    if (!mounted) return;

    Navigator.of(context).pop(false);
  }

  /// La forma che l'archivio locale e il diario si aspettano.
  ///
  /// 💡 È la **stessa** di un piano arrivato via chat: da qui in poi un piano
  /// importato e uno ricevuto sono indistinguibili, ed è giusto — un piano è un
  /// piano, e due forme diverse vorrebbero dire due strade da mantenere.
  Map<String, dynamic> _perLArchivio() => {
    'name': _nome.text.trim(),
    'days': _giorni.map((g) => g.perLArchivio()).toList(),
  };
}

// ───────────────────────── i pezzi ─────────────────────────

class _Intestazione extends StatelessWidget {
  const _Intestazione({required this.righe, required this.nomeFile});

  final int righe;
  final String nomeFile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$righe righe da controllare',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              'Le ha ricopiate un modello da «$nomeFile». Confrontale con '
              'l\'originale: un grammaggio letto male non dà nessun errore, '
              'sembra un valore come gli altri.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// I punti in cui il modello ha detto di non essere sicuro.
///
/// 🚨 **Stanno in cima e si vedono.** Sono l'unica cosa che porta chi controlla
/// dritto sulle righe che contano: senza, la revisione è un elenco di trenta
/// voci tutte uguali, e chi la fa si stanca alla decima — proprio prima di
/// arrivare a quella sbagliata.
class _Dubbi extends StatelessWidget {
  const _Dubbi({required this.dubbi});

  final List<String> dubbi;

  @override
  Widget build(BuildContext context) {
    final colori = Theme.of(context).colorScheme;

    return Card(
      color: colori.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.priority_high, color: colori.onErrorContainer),
                const SizedBox(width: Gap.xs),
                Expanded(
                  child: Text(
                    'Guarda prima questi punti',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colori.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            for (final dubbio in dubbi)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Text(
                  '• $dubbio',
                  style: TextStyle(color: colori.onErrorContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GiornoCard extends StatelessWidget {
  const _GiornoCard({required this.giorno, required this.apriOriginale});

  final _Giorno giorno;
  final Future<void> Function() apriOriginale;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    giorno.nome,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // ⚠️ L'originale si apre da ogni giorno, non solo dalla barra
                // in alto: chi sta confrontando la riga 24 non deve risalire.
                IconButton(
                  tooltip: 'Confronta con l\'originale',
                  onPressed: apriOriginale,
                  icon: const Icon(Icons.compare_arrows),
                ),
              ],
            ),
            for (final pasto in giorno.pasti) ...[
              const Divider(),
              Text(pasto.etichetta, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: Gap.xs),
              for (final alimento in pasto.alimenti) _RigaAlimento(alimento: alimento),
            ],
          ],
        ),
      ),
    );
  }
}

class _RigaAlimento extends StatelessWidget {
  const _RigaAlimento({required this.alimento});

  final _Alimento alimento;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: alimento.descrizione,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Alimento',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: TextField(
              controller: alimento.quantita,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                labelText: 'g',
                border: const OutlineInputBorder(),
                /*
                 * 🚨 Un campo vuoto non è un errore: è il modello che ha detto
                 * «qui non ero sicuro» invece di inventare. Va riempito
                 * guardando l'originale, e il suggerimento lo dice.
                 */
                hintText: alimento.quantita.text.isEmpty ? '—' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── lo stato del modulo ─────────────────────────
//
// 🚨 Mutabile e con i controller dentro, come `piano_alimentare.dart`: è lo
// stato di un modulo che si sta compilando, non un dato che il server ha già
// deciso. Ricostruire l'albero a ogni carattere digitato si sentirebbe.

class _Giorno {
  _Giorno({required this.nome, required this.pasti});

  factory _Giorno.da(Map<String, dynamic> dati) => _Giorno(
    nome: dati['nome']?.toString() ?? 'Giorno',
    pasti: ((dati['pasti'] as List?) ?? const [])
        .whereType<Map>()
        .map((p) => _Pasto.da(p.cast<String, dynamic>()))
        .toList(),
  );

  final String nome;
  final List<_Pasto> pasti;

  void smonta() {
    for (final pasto in pasti) {
      pasto.smonta();
    }
  }

  Map<String, dynamic> perLArchivio() => {
    'name': nome,
    'meals': pasti.map((p) => p.perLArchivio()).toList(),
  };
}

class _Pasto {
  _Pasto({required this.tipo, required this.orario, required this.alimenti});

  factory _Pasto.da(Map<String, dynamic> dati) => _Pasto(
    tipo: dati['tipo']?.toString(),
    orario: dati['orario']?.toString(),
    alimenti: ((dati['alimenti'] as List?) ?? const [])
        .whereType<Map>()
        .map((a) => _Alimento.da(a.cast<String, dynamic>()))
        .toList(),
  );

  final String? tipo;
  final String? orario;
  final List<_Alimento> alimenti;

  String get etichetta {
    final nome = switch (tipo) {
      'breakfast' => 'Colazione',
      'lunch' => 'Pranzo',
      'dinner' => 'Cena',
      'snack' => 'Spuntino',
      final altro when altro != null && altro.isNotEmpty => altro,
      _ => 'Pasto',
    };

    return orario == null || orario!.isEmpty ? nome : '$nome · $orario';
  }

  void smonta() {
    for (final alimento in alimenti) {
      alimento.smonta();
    }
  }

  Map<String, dynamic> perLArchivio() => {
    'meal': tipo ?? 'snack',
    if (orario != null && orario!.isNotEmpty) 'time': orario,
    'items': alimenti.map((a) => a.perLArchivio()).toList(),
  };
}

class _Alimento {
  _Alimento({required this.descrizione, required this.quantita});

  factory _Alimento.da(Map<String, dynamic> dati) {
    final grammi = (dati['grammi'] as num?)?.toDouble();

    return _Alimento(
      descrizione: TextEditingController(
        text: dati['descrizione']?.toString() ?? '',
      ),
      /*
       * ⚠️ Se i grammi mancano ma c'è una quantità a parole («un cucchiaio»),
       * la si tiene nella descrizione e il campo numerico resta vuoto. Riempirlo
       * con una conversione inventata sarebbe esattamente il tipo di errore che
       * questa schermata esiste per intercettare.
       */
      quantita: TextEditingController(text: grammi == null ? '' : _pulito(grammi)),
    );
  }

  final TextEditingController descrizione;
  final TextEditingController quantita;

  static String _pulito(double valore) =>
      valore == valore.roundToDouble() ? valore.round().toString() : valore.toString();

  void smonta() {
    descrizione.dispose();
    quantita.dispose();
  }

  Map<String, dynamic> perLArchivio() {
    final grammi = double.tryParse(quantita.text.trim().replaceAll(',', '.'));

    return {
      'description': descrizione.text.trim(),
      'grams': ?grammi,
    };
  }
}
