import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/cassaforte.dart';
import '../../../core/crypto/file_di_backup.dart';
import '../../../core/crypto/providers_crypto.dart';
import '../../../core/theme/app_theme.dart';

/// Il ripristino su un dispositivo nuovo — S6.7.
///
/// ── 🚨 La sequenza, e perché quest'ordine e non un altro ──────────────────
///
/// ```
/// accesso ──► esiste un pacchetto sul server?
///                │
///                ├── no  ──► crei la password (schermata precedente)
///                │
///                └── sì  ──► QUESTA schermata
///                            1. hai la password?      → si riapre tutto
///                            2. hai il file di backup? → si riapre tutto
///                            3. nessuna delle due     → si riparte da capo
/// ```
///
/// 🚨 **Il terzo ramo è distruttivo e va scritto come tale.** Ripartire da capo
/// vuol dire generare una chiave maestra nuova, e da quel momento **i messaggi
/// vecchi non si riaprono più da nessuna parte** — nemmeno ritrovando la
/// password domani, perché il pacchetto che la conteneva sarà stato sostituito.
///
/// ⚠️ Per questo il pulsante che ci porta è l'ultimo, non è colorato, e chiede
/// una conferma esplicita: è l'unica azione irreversibile di tutta l'app dopo
/// la cancellazione dell'account.
///
/// 💡 *«Ao, pace: hai perso qualche mese di dati che tanto stanno su Google
/// Health.»* — il committente. Ed è vero per sonno, battito e HRV, che valgono
/// giorni; **non** per peso, diario e storico, che valgono anni. Quelli però li
/// porta il ripristino di sistema, che è già avvenuto prima di arrivare qui.
class SchermataRipristino extends ConsumerStatefulWidget {
  const SchermataRipristino({super.key});

  @override
  ConsumerState<SchermataRipristino> createState() => _SchermataRipristinoState();
}

class _SchermataRipristinoState extends ConsumerState<SchermataRipristino> {
  final _password = TextEditingController();

  bool _inCorso = false;
  String? _errore;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _conPassword() async {
    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      final servizio = await ref.read(servizioChiaviProvider.future);
      await servizio.ripristinaConPassword(_password.text);

      ref.invalidate(statoChiaviProvider);

      if (mounted) Navigator.of(context).pop(true);
    } on PasswordDiRecuperoSbagliata {
      _fallito('Questa password non apre il tuo account. Riprova.');
    } on Object catch (e) {
      _fallito(e.toString());
    }
  }

  /// Il ripristino dal file esportato.
  ///
  /// ⚠️ **Riscrive il pacchetto sul server con una password nuova**: chi arriva
  /// di qui è per definizione qualcuno che quella vecchia non ce l'ha più.
  Future<void> _conFile() async {
    final scelta = await showDialog<_DatiDelFile>(
      context: context,
      builder: (_) => const _ChiediFileECodice(),
    );

    if (scelta == null) return;

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      final sodium = await ref.read(sodiumProvider.future);
      final servizio = await ref.read(servizioChiaviProvider.future);

      final contenuto = FileDiBackup(sodium).importa(
        file: await File(scelta.percorso).readAsBytes(),
        codice: scelta.codice,
      );

      await servizio.ripristinaDaChiave(
        chiaveMaestra: contenuto.chiaveMaestra,
        nuovaPassword: scelta.nuovaPassword,
      );

      ref.invalidate(statoChiaviProvider);

      if (mounted) Navigator.of(context).pop(true);
    } on CodiceDiRipristinoSbagliato catch (e) {
      _fallito(e.motivo);
    } on FileSystemException {
      _fallito('Non riesco a leggere quel file.');
    } on Object catch (e) {
      _fallito(e.toString());
    }
  }

  /// L'ultima spiaggia: si riparte da zero.
  Future<void> _ricomincia() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ricominciare da capo?'),
        content: const Text(
          'I messaggi che hai scambiato finora non si riapriranno più, '
          'nemmeno se ritrovassi la password domani.\n\n'
          'Il peso, il diario e lo storico degli allenamenti non si toccano.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Ricomincia'),
          ),
        ],
      ),
    );

    if (conferma != true || !mounted) return;

    final nuova = await showDialog<String>(
      context: context,
      builder: (_) => const _ChiediNuovaPassword(),
    );

    if (nuova == null) return;

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      final sodium = await ref.read(sodiumProvider.future);
      final servizio = await ref.read(servizioChiaviProvider.future);

      // 🚨 Una chiave maestra nuova di zecca. È il punto di non ritorno, e
      // arriva **solo** dopo due conferme e due tentativi di ripristino.
      await servizio.ripristinaDaChiave(
        chiaveMaestra: Cassaforte(sodium).generaChiaveMaestra().extractBytes(),
        nuovaPassword: nuova,
      );

      ref.invalidate(statoChiaviProvider);

      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      _fallito(e.toString());
    }
  }

  void _fallito(String messaggio) {
    if (!mounted) return;

    setState(() {
      _errore = messaggio;
      _inCorso = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ritrova il tuo account'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          Text(
            'Hai già usato questa app',
            style: testo.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'I tuoi messaggi sono chiusi a chiave. Per riaprirli su questo '
            'telefono serve la password di recupero che avevi creato.',
            style: testo.bodyMedium,
          ),
          const SizedBox(height: Gap.lg),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password di recupero'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _password.text.isEmpty ? null : _conPassword(),
          ),
          if (_errore != null) ...[
            const SizedBox(height: Gap.md),
            Text(
              _errore!,
              style: testo.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: Gap.lg),
          FilledButton(
            onPressed: _password.text.isEmpty || _inCorso ? null : _conPassword,
            child: _inCorso
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Riapri il mio account'),
          ),
          const Divider(height: Gap.lg * 2),
          Text('Non ce l\'hai più?', style: testo.titleMedium),
          const SizedBox(height: Gap.sm),
          Text(
            'Se avevi esportato un file di backup, quello basta: dentro c\'è '
            'la chiave, e ti chiederemo solo di scegliere una password nuova.',
            style: testo.bodyMedium,
          ),
          const SizedBox(height: Gap.md),
          OutlinedButton.icon(
            onPressed: _inCorso ? null : _conFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Uso il file di backup'),
          ),
          const SizedBox(height: Gap.lg),
          TextButton(
            onPressed: _inCorso ? null : _ricomincia,
            child: const Text('Non ho né la password né il file'),
          ),
        ],
      ),
    );
  }
}

/// Percorso del file, codice di ripristino e password nuova.
class _DatiDelFile {
  const _DatiDelFile({
    required this.percorso,
    required this.codice,
    required this.nuovaPassword,
  });

  final String percorso;
  final String codice;
  final String nuovaPassword;
}

class _ChiediFileECodice extends StatefulWidget {
  const _ChiediFileECodice();

  @override
  State<_ChiediFileECodice> createState() => _ChiediFileECodiceState();
}

class _ChiediFileECodiceState extends State<_ChiediFileECodice> {
  final _percorso = TextEditingController();
  final _codice = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _percorso.dispose();
    _codice.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valido =>
      _percorso.text.trim().isNotEmpty &&
      FileDiBackup.normalizza(_codice.text).length == 24 &&
      _password.text.length >= 8;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ripristino da file'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _percorso,
              decoration: const InputDecoration(
                labelText: 'Percorso del file',
                hintText: '/storage/…/training-companion.backup',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Gap.md),
            TextField(
              controller: _codice,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Codice di ripristino',
                hintText: 'ABCD-EFGH-JKLM-NPQR-STUV-WXYZ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Gap.md),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nuova password di recupero',
                helperText: 'Almeno 8 caratteri',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _valido
              ? () => Navigator.of(context).pop(_DatiDelFile(
                    percorso: _percorso.text.trim(),
                    codice: _codice.text,
                    nuovaPassword: _password.text,
                  ))
              : null,
          child: const Text('Ripristina'),
        ),
      ],
    );
  }
}

class _ChiediNuovaPassword extends StatefulWidget {
  const _ChiediNuovaPassword();

  @override
  State<_ChiediNuovaPassword> createState() => _ChiediNuovaPasswordState();
}

class _ChiediNuovaPasswordState extends State<_ChiediNuovaPassword> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scegli una password di recupero'),
      content: TextField(
        controller: _password,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Password di recupero',
          helperText: 'Almeno 8 caratteri',
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _password.text.length >= 8
              ? () => Navigator.of(context).pop(_password.text)
              : null,
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}
