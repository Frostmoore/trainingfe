/// Importare una scheda o un piano da un documento — Parte K, K5.
///
/// ══ 🚨 COSA FA DAVVERO QUESTA FUNZIONE, DETTO SENZA GIRI ══════════════════
///
/// **Ricopia**, non elabora. Il documento l'ha scritto qualcun altro fuori di
/// qui — nel caso di una dieta un medico, un biologo nutrizionista o un
/// dietista — e noi lo trasformiamo in righe che l'app sa leggere. Elaborare
/// una dieta è un atto riservato (art. 348 c.p.), e non è quello che succede
/// qui.
///
/// ⚠️ Per questo si chiede una **dichiarazione** e non una spunta di comodo, e
/// per questo la trascrizione va **controllata riga per riga** prima di
/// diventare qualcosa: la revisione è il compositore vero, già compilato.
///
/// ══ ⛔ UNA SOLA SCHERMATA PER TUTTI E DUE ═════════════════════════════════
///
/// Schede e piani si importano allo stesso modo: stesso limite di file, stesso
/// prezzo, stesso consenso, stessa attesa. 🚨 Due schermate gemelle vorrebbero
/// dire due posti dove correggere ogni cosa, e quella meno percorsa si romperebbe
/// in silenzio — è lo stesso motivo per cui di là c'è **un** controller.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/avvertenza_nutrizionale.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../auth/auth_controller.dart';
import '../../nutrition/ui/compositore_piano.dart';
import '../../training/ui/compositore_scheda.dart';
import '../data/bozza_in_modulo.dart';
import '../data/documento_scelto.dart';
import '../data/importazione_da_documento.dart';
import '../data/origine_della_bozza.dart';
import 'avviso_dei_giorni.dart';
import 'consenso_del_documento.dart';

class ImportaDocumentoScreen extends ConsumerStatefulWidget {
  const ImportaDocumentoScreen({required this.genere, super.key});

  final GenereImportato genere;

  /// 💡 Costa 50 gettoni, ed è scritto **prima** di scegliere il file: scoprire
  /// il prezzo dopo aver caricato è il modo di far arrabbiare qualcuno per un
  /// numero che avrebbe accettato senza problemi.
  static const gettoni = 50;

  /// 🚨 Lo stesso tetto del server (`ImportazioneDaDocumento::BYTE_MASSIMI`).
  ///
  /// ⚠️ Si controlla **prima di caricare**: mandare dieci megabyte per poi
  /// ricevere un 422 vuol dire aver consumato il piano dati di qualcuno per
  /// niente, e su rete mobile metterci anche un minuto prima di dirglielo.
  ///
  /// ⛔ E si controlla sulla **somma**, non sul singolo file: cinque fotografie
  /// da otto megabyte passerebbero una a una e verrebbero rifiutate insieme.
  static const tetto = 10 * 1024 * 1024;

  @override
  ConsumerState<ImportaDocumentoScreen> createState() =>
      _ImportaDocumentoScreenState();
}

class _ImportaDocumentoScreenState
    extends ConsumerState<ImportaDocumentoScreen> {
  final _scelta = const SceltaDeiDocumenti();

  DocumentiScelti? _documenti;
  bool _dichiarazione = false;
  bool _inCorso = false;
  String? _errore;
  String? _passo;

  bool get _eScheda => widget.genere == GenereImportato.scheda;

  @override
  Widget build(BuildContext context) {
    final documenti = _documenti;

    return Scaffold(
      appBar: IntestazioneApp(
        titolo: _eScheda ? 'Importa una scheda' : 'Importa un piano',
      ),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          _Spiegazione(scheda: _eScheda),
          const SizedBox(height: Gap.md),

          /*
           * ══ 📌 L'AVVERTENZA SULLE IMMAGINI, PAROLA PER PAROLA ═══════════
           *
           * Il committente, il 03/09/2026. ⚠️ Sta **prima** della scelta e non
           * dopo: detta dopo non cambierebbe niente, perché a quel punto la
           * fotografia l'ha già fatta.
           */
          const _AvvertenzaSulleImmagini(),
          const SizedBox(height: Gap.md),

          _SceltaDeiFile(
            documenti: documenti,
            attivo: !_inCorso,
            onFile: _dagliFile,
            onScatto: _unoScatto,
            onSvuota: () => setState(() => _documenti = null),
          ),

          const SizedBox(height: Gap.md),

          CheckboxListTile(
            value: _dichiarazione,
            onChanged: _inCorso
                ? null
                : (v) => setState(() => _dichiarazione = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              _eScheda
                  ? 'Dichiaro che questa scheda me l\'ha data chi mi segue in '
                        'palestra, o l\'ho scritta io, e che la importo sotto '
                        'la mia responsabilità.'
                  : 'Dichiaro che questo piano è stato redatto da un '
                        'professionista abilitato (medico, biologo '
                        'nutrizionista o dietista) e che lo importo sotto la '
                        'mia responsabilità.',
            ),
          ),

          const SizedBox(height: Gap.md),

          if (_passo != null) ...[
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(child: Text(_passo!)),
              ],
            ),
            const SizedBox(height: Gap.md),
          ],

          if (_errore != null) ...[
            Text(
              _errore!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: Gap.md),
          ],

          FilledButton.icon(
            /*
             * 🚨 Spento finché non c'è **tutto**: i file e la dichiarazione. Il
             * server la pretende comunque (`accepted`), ma far scegliere un
             * documento per poi rifiutarlo sarebbe una lezione inutile.
             */
            onPressed: documenti != null && _dichiarazione && !_inCorso
                ? _manda
                : null,
            icon: const Icon(Icons.auto_awesome),
            label: const Text(
              'Manda e trascrivi · '
              '${ImportaDocumentoScreen.gettoni} gettoni',
            ),
          ),

          const SizedBox(height: Gap.lg),

          // ⚠️ Solo per i piani: su una scheda non c'entra niente, e
          // un'avvertenza fuori posto insegna a saltarle tutte.
          if (!_eScheda) const AvvertenzaNutrizionale(),
        ],
      ),
    );
  }

  // ───────────────────────── la scelta ─────────────────────────

  Future<void> _dagliFile() async {
    final scelti = await _scelta.daiFile();

    if (scelti == null || !mounted) return;

    setState(() {
      _documenti = scelti;
      _errore = _troppoGrande(scelti);
    });
  }

  /// ⚠️ **Uno scatto si aggiunge a quelli di prima**, non li sostituisce: una
  /// scheda su carta sono spesso due o tre pagine, e ricominciare da capo a ogni
  /// foto renderebbe impossibile fotografarne più di una.
  Future<void> _unoScatto() async {
    final scatto = await _scelta.unoScatto();

    if (scatto == null || !mounted) return;

    final prima = _documenti?.documenti ?? const <DocumentoScelto>[];

    if (prima.length >= SceltaDeiDocumenti.alMassimo) {
      setState(
        () => _errore =
            'Più di ${SceltaDeiDocumenti.alMassimo} pagine non riesco a '
            'leggerle in una volta.',
      );

      return;
    }

    final scelti = DocumentiScelti(
      documenti: [...prima, scatto],

      /*
       * 🚨 Da qui in poi è **immagini** comunque: uno scatto in mezzo a dei PDF
       * rende l'insieme meno affidabile, e l'avvertenza deve dirlo.
       */
      tipo: TipoDiDocumento.immagini,
    );

    setState(() {
      _documenti = scelti;
      _errore = _troppoGrande(scelti);
    });
  }

  String? _troppoGrande(DocumentiScelti scelti) =>
      scelti.byteTotali > ImportaDocumentoScreen.tetto
      ? 'Insieme superano i 10 MB: non riesco a caricarli. Prova con meno '
            'pagine, o con il PDF invece delle fotografie.'
      : null;

  // ───────────────────────── il viaggio ─────────────────────────

  /// Chiede il consenso, carica, aspetta, e apre il compositore già compilato.
  Future<void> _manda() async {
    final scelti = _documenti;

    if (scelti == null || _troppoGrande(scelti) != null) return;

    /*
     * ══ 🔴 IL CONSENSO SPECIFICO, PRIMA DI QUALUNQUE BYTE ════════════════
     *
     * 📌 *«si deve richiedere il consenso specifico a mandare quei dati
     * all'AI»*. 🚨 Qui, e non in fondo a questa schermata: una casella in mezzo
     * a un modulo si spunta senza leggere, e questa è l'ultima occasione in cui
     * qualcuno può ancora coprire il proprio nome sul foglio.
     */
    final consenso = await ConsensoDelDocumento.chiedi(
      context,
      quanti: scelti.quanti,
      tipo: scelti.tipo,
    );

    if (!consenso || !mounted) return;

    setState(() {
      _inCorso = true;
      _errore = null;
      _passo = scelti.quanti == 1
          ? 'Carico il documento…'
          : 'Carico ${scelti.quanti} pagine…';
    });

    try {
      final importazioni = ref.read(importazioniProvider);

      var importazione = await importazioni.carica(
        documenti: scelti.documenti,
        dichiarazione: true,
        consensoDocumento: true,
        genere: widget.genere,
      );

      if (!mounted) return;

      setState(
        () => _passo = _eScheda
            ? 'Sto ricopiando la scheda: ci vuole un minuto…'
            : 'Sto ricopiando il piano: ci vuole un minuto…',
      );

      importazione = await _aspetta(importazione.id);

      if (!mounted) return;

      if (importazione.stato == StatoImportazione.fallita) {
        setState(() {
          _errore =
              'Non sono riuscito a leggere questo documento. '
              '${importazione.errore ?? ''}\n\n'
              'I gettoni non sono stati scalati.';
          _inCorso = false;
          _passo = null;
        });

        return;
      }

      setState(() {
        _inCorso = false;
        _passo = null;
      });

      await _apriLaRevisione(importazione, scelti);
    } on Object catch (e) {
      if (!mounted) return;

      setState(() {
        _errore = ApiClient.unwrapError(e).message;
        _inCorso = false;
        _passo = null;
      });
    }
  }

  /// Apre il compositore vero, già compilato.
  ///
  /// ⛔ **Non una schermata di revisione tutta sua**: due editor dello stesso
  /// oggetto divergono, e quello dell'import resta indietro senza che nessun
  /// test diventi rosso.
  Future<void> _apriLaRevisione(
    ImportazioneDaDocumento importazione,
    DocumentiScelti scelti,
  ) async {
    final origine = OrigineDellaBozza(
      importazioneId: importazione.id,
      documenti: [for (final d in scelti.documenti) d.relativo],
      tipo: importazione.tipo,
      righeDaControllare: importazione.righe,
      dubbi: importazione.dubbi,
    );

    final bozza = importazione.bozza ?? const <String, dynamic>{};

    /*
     * ══ 🚨 L'AVVISO DEI GIORNI, PRIMA DELLA REVISIONE ═══════════════════
     *
     * 📌 Il committente: *«si avverte prima e via»*. ⛔ Dirlo **dopo** che
     * qualcuno ha confrontato quaranta righe è il momento peggiore possibile
     * per annunciare che la sua scheda diventerà quattro.
     */
    if (_eScheda) {
      final abbonato = ref.read(authControllerProvider).user?.abbonato ?? false;
      final giorni = importazione.giorni;

      if (!abbonato && giorni > 1) {
        final avanti = await AvvisoDeiGiorni.mostra(context, giorni: giorni);

        if (!avanti || !mounted) return;
      }
    }

    final salvato = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _eScheda
            ? CompositoreScheda(
                bozza: schedaDallaBozza(bozza),
                origine: origine,
              )
            : CompositorePiano(bozza: pianoDallaBozza(bozza), origine: origine),
      ),
    );

    if (!mounted) return;

    if (salvato ?? false) Navigator.of(context).pop(true);
  }

  /// Aspetta che il job finisca, chiedendo ogni tre secondi.
  ///
  /// ══ ⚠️ PERCHE' SI CHIEDE INVECE DI RICEVERE ════════════════════════════
  ///
  /// Perché è **una volta sola**, dura un minuto e finisce. Aprire un canale
  /// realtime per un evento che accade una volta per importazione vorrebbe dire
  /// mantenere un pezzo di infrastruttura per il caso più raro che abbiamo.
  ///
  /// 🚨 **E c'è un limite di tentativi.** Senza, un job morto lascerebbe una
  /// rotellina che gira per sempre — che è il modo peggiore di fallire, perché
  /// non dice niente e non finisce mai.
  Future<ImportazioneDaDocumento> _aspetta(int id) async {
    final importazioni = ref.read(importazioniProvider);

    for (var tentativo = 0; tentativo < 40; tentativo++) {
      await Future<void>.delayed(const Duration(seconds: 3));

      if (!mounted) throw StateError('Schermata chiusa.');

      final stato = await importazioni.stato(id);

      if (!stato.inLavorazione) return stato;
    }

    throw TimeoutException('La trascrizione ci sta mettendo troppo.');
  }
}

// ───────────────────────── i pezzi ─────────────────────────

class _Spiegazione extends StatelessWidget {
  const _Spiegazione({required this.scheda});

  final bool scheda;

  @override
  Widget build(BuildContext context) {
    final testi = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Come funziona', style: testi.titleMedium),
            const SizedBox(height: Gap.sm),
            Text(
              scheda
                  ? 'Carichi il PDF o le fotografie della scheda che ti hanno '
                        'dato. Un modello la ricopia riga per riga, tu la '
                        'controlli nello stesso editor con cui scriveresti una '
                        'scheda da zero, e solo allora diventa la tua.'
                  : 'Carichi il PDF o le fotografie del piano che ti ha dato il '
                        'tuo professionista. Un modello lo ricopia riga per '
                        'riga, tu lo controlli nello stesso editor con cui '
                        'scriveresti un piano da zero, e solo allora diventa il '
                        'tuo.',
              style: testi.bodyMedium,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Resta sul tuo telefono. Quello che carichi viene cancellato dal '
              'server appena la trascrizione è finita.',
              style: testi.bodySmall,
            ),
            if (!scheda) ...[
              const SizedBox(height: Gap.sm),
              Text(
                'Nessuno qui dentro elabora diete: quello lo ha già fatto chi '
                'ha firmato il tuo piano.',
                style: testi.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvvertenzaSulleImmagini extends StatelessWidget {
  const _AvvertenzaSulleImmagini();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                'Per risultati ottimali, si consiglia di usare un documento in '
                'PDF. L\'analisi delle immagini è generalmente meno accurata '
                'di quella dei PDF. Potrai comunque correggere a mano ogni '
                'riga.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceltaDeiFile extends StatelessWidget {
  const _SceltaDeiFile({
    required this.documenti,
    required this.attivo,
    required this.onFile,
    required this.onScatto,
    required this.onSvuota,
  });

  final DocumentiScelti? documenti;
  final bool attivo;
  final VoidCallback onFile;
  final VoidCallback onScatto;
  final VoidCallback onSvuota;

  @override
  Widget build(BuildContext context) {
    final scelti = documenti;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: attivo ? onFile : null,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Scegli i file'),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: attivo ? onScatto : null,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Fotografa'),
                  ),
                ),
              ],
            ),
            if (scelti != null) ...[
              const SizedBox(height: Gap.sm),

              /*
               * 💡 **Si vedono uno per uno, nell'ordine.** Per delle pagine
               * fotografate l'ordine è l'informazione principale: la seconda
               * letta per prima dà una scheda che comincia da metà.
               */
              for (final (i, d) in scelti.documenti.indexed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 12, child: Text('${i + 1}')),
                  title: Text(
                    d.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              TextButton.icon(
                onPressed: attivo ? onSvuota : null,
                icon: const Icon(Icons.close),
                label: const Text('Ricomincio da capo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
