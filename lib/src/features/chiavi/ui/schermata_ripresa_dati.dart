import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_controller.dart';
import '../../../core/crypto/cassaforte.dart';
import '../../../core/crypto/providers_crypto.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../auth/auth_controller.dart';

/// La ripresa dei dati, dall'inizio alla fine, con davanti qualcosa da guardare.
///
/// ── 🚨 Perché una schermata e non un dialogo ──────────────────────────────
///
/// Perché il dialogo **spariva appena si toccava «Riprendi»**, e poi partivano
/// in fila la chiamata al server per la chiave, lo scarico da Drive, la
/// decifratura e la riscrittura di **diecimila righe** — con lo schermo fermo su
/// «Oggi» e niente sopra.
///
/// ⚠️ Il committente l'ha detto così: *«c'è stato un delay molto accentuato tra
/// quando ho detto recupera i dati e quando effettivamente sono stati
/// ripristinati»*. Non era lento: era **muto**. E un'attesa muta di dieci
/// secondi è indistinguibile da un guasto.
///
/// 💡 Qui invece si vede **a che punto è**, e alla fine si vede **com'è andata**.
///
/// ── ⚠️ E i passi si dicono, non si nascondono ─────────────────────────────
///
/// *«prima cerca di accedere al profilo giusto, poi mi chiede a quale profilo
/// accedere, poi non mi dice che ha ripristinato»*. Erano passi tecnici lasciati
/// a vista, ognuno con la propria finestra di sistema. Adesso stanno **dentro
/// una schermata sola** che li racconta in ordine.
class SchermataRipresaDati extends ConsumerStatefulWidget {
  const SchermataRipresaDati({super.key});

  @override
  ConsumerState<SchermataRipresaDati> createState() =>
      _SchermataRipresaDatiState();
}

/// A che punto è la ripresa.
enum _Passo {
  password('Scrivi la password di recupero'),
  chiave('Sto aprendo la tua cassaforte…'),
  dati('Sto riprendendo i tuoi dati…'),
  fatto('Fatto'),
  errore('Non è andata');

  const _Passo(this.titolo);

  final String titolo;
}

class _SchermataRipresaDatiState extends ConsumerState<SchermataRipresaDati> {
  final _password = TextEditingController();

  _Passo _passo = _Passo.password;
  String? _errore;
  int _quante = 0;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _riprendi() async {
    if (_password.text.isEmpty) return;

    setState(() {
      _passo = _Passo.chiave;
      _errore = null;
    });

    try {
      /*
       * 🚨 **L'ordine non è scambiabile**: prima la chiave, poi l'archivio.
       *
       * Il file su Drive è avvolto con la chiave maestra. Provare a scaricarlo
       * prima vorrebbe dire avere in mano dei byte e niente con cui aprirli.
       */
      final servizio = await ref.read(servizioChiaviProvider.future);

      await servizio.ripristinaConPassword(_password.text);

      if (!mounted) return;

      setState(() => _passo = _Passo.dati);

      final quante = await ref
          .read(backupAutomaticoProvider.notifier)
          .ripristinaDalCloudERiaccendi();

      /*
       * 💡 **Si ricarica l'utente, ma non e' piu' un cerotto.**
       *
       * Fino al 19/08 serviva **per forza**: `authControllerProvider` osservava
       * l'archivio locale, e riaprirlo lo faceva ricreare **senza utente** —
       * nome e foto sparivano dall'intestazione. 🚨 Quella dipendenza e'
       * stata **tolta** (vedi `AuthController._svuotaLArchivio`), quindi adesso
       * il controller sopravvive al ripristino.
       *
       * ⚠️ La riga resta perche' e' **giusta comunque**: un ripristino puo'
       * riportare un profilo cambiato altrove, e richiederlo al server dopo e'
       * il modo di mostrarlo aggiornato. Prima era una pezza, adesso e' una
       * scelta.
       */
      await ref.read(authControllerProvider.notifier).refresh();

      ref.invalidate(statoChiaviProvider);

      if (!mounted) return;

      setState(() {
        _quante = quante;
        _passo = _Passo.fatto;
      });
    } on PasswordDiRecuperoSbagliata {
      _fallito('Questa password non apre il tuo account. Riprova.');
    } on Object catch (e) {
      _fallito(e.toString());
    }
  }

  void _fallito(String motivo) {
    if (!mounted) return;

    setState(() {
      _passo = _Passo.errore;
      _errore = motivo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final inCorso = _passo == _Passo.chiave || _passo == _Passo.dati;

    return PopScope(
      /*
       * 🚨 **Non si esce mentre sta scrivendo l'archivio.**
       *
       * ⚠️ Uscire a metà lascerebbe un archivio riscritto per metà — cioè il
       * caso peggiore: non i dati vecchi e non quelli nuovi.
       */
      canPop: !inCorso,
      child: Scaffold(
        appBar: IntestazioneApp(
          titolo: 'Riprendi i tuoi dati',
          // ⛔ Mentre il ripristino gira non si torna indietro: interromperlo a
          // meta' lascerebbe i dati in uno stato che nessuno sa leggere.
          indietro: !inCorso,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  switch (_passo) {
                    _Passo.fatto => Icons.check_circle_outline,
                    _Passo.errore => Icons.error_outline,
                    _ => Icons.cloud_download_outlined,
                  },
                  size: 56,
                  color: switch (_passo) {
                    _Passo.errore => tema.colorScheme.error,
                    _ => tema.colorScheme.primary,
                  },
                ),
                const SizedBox(height: Gap.md),

                Text(
                  _passo.titolo,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.titleLarge,
                ),
                const SizedBox(height: Gap.md),

                if (_passo == _Passo.password) ...[
                  Text(
                    'È quella che hai scelto quando hai attivato la copia di '
                    'sicurezza. Senza, il file non si apre: nemmeno noi '
                    'possiamo.',
                    style: tema.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Gap.md),
                  TextField(
                    controller: _password,
                    autofocus: true,
                    obscureText: true,
                    onSubmitted: (_) => _riprendi(),
                    decoration: const InputDecoration(
                      labelText: 'Password di recupero',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: Gap.lg),
                  FilledButton(
                    onPressed: _riprendi,
                    child: const Text('Riprendi'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Più tardi'),
                  ),
                ],

                if (inCorso) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: Gap.md),
                  Text(
                    /*
                     * 💡 Si dice **quanto può durare**, perché dieci secondi
                     * senza un'idea della fine sembrano un blocco. E si dice di
                     * non chiudere, perché è vero.
                     */
                    'Ci vuole qualche secondo: sto rimettendo a posto diario, '
                    'allenamenti, misure e foto.\n\nNon chiudere l\'app.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],

                if (_passo == _Passo.fatto) ...[
                  Text(
                    'Ho rimesso a posto $_quante cose.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Gap.lg),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Continua'),
                  ),
                ],

                if (_passo == _Passo.errore) ...[
                  Text(
                    _errore ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tema.colorScheme.error),
                  ),
                  const SizedBox(height: Gap.lg),
                  FilledButton(
                    onPressed: () => setState(() => _passo = _Passo.password),
                    child: const Text('Riprova'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Più tardi'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
