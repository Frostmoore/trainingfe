import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/providers_crypto.dart';
import '../../../core/theme/app_theme.dart';

/// Creare la password di recupero — S6.4.
///
/// ── 🚨 Perché questa schermata è scritta così, e non con una casella ───────
///
/// *«Chi la dimentica perde tutto.»* Non è una formula di rito: senza questa
/// password non si rientra nei propri messaggi e — dopo S7 — nemmeno nelle
/// proprie schede e nei propri piani alimentari. **Non possiamo recuperarla per
/// nessuno**, ed è esattamente la proprietà per cui il sistema esiste: se
/// potessimo recuperarla, potremmo leggere.
///
/// Per questo la spiegazione sta **nella schermata in cui la password si crea**,
/// a caratteri grandi, e non in una casella da spuntare in fondo a un modulo —
/// che è il posto dove le cose importanti vanno a non essere lette.
class SchermataPasswordDiRecupero extends ConsumerStatefulWidget {
  const SchermataPasswordDiRecupero({super.key});

  @override
  ConsumerState<SchermataPasswordDiRecupero> createState() =>
      _SchermataPasswordDiRecuperoState();
}

class _SchermataPasswordDiRecuperoState
    extends ConsumerState<SchermataPasswordDiRecupero> {
  final _password = TextEditingController();
  final _conferma = TextEditingController();

  bool _inCorso = false;
  bool _hoCapito = false;
  String? _errore;

  @override
  void dispose() {
    _password.dispose();
    _conferma.dispose();
    super.dispose();
  }

  /// ⚠️ Otto caratteri non sono una password forte, e non è un refuso.
  ///
  /// Il pacchetto incartato sta sul nostro server e si attaccherebbe *offline*:
  /// la difesa vera è **Argon2id**, non una regola sui caratteri. Le regole
  /// arzigogolate — maiuscola, numero, simbolo — producono `Password1!` e la
  /// fanno **dimenticare**, che qui è il guasto peggiore di tutti.
  static const int lunghezzaMinima = 8;

  bool get _valida =>
      _password.text.length >= lunghezzaMinima &&
      _password.text == _conferma.text &&
      _hoCapito;

  Future<void> _salva() async {
    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      final servizio = await ref.read(servizioChiaviProvider.future);
      await servizio.creaPasswordDiRecupero(_password.text);

      /*
       * 🚨 **NIENTE `Navigator.pop()`, ed è un difetto pagato: pagina nera.**
       *
       * Questa schermata non è **spinta sopra** a niente: è il corpo che
       * `PortaDelleChiavi` disegna al posto della chat finché la chiave non
       * c'è. Un `pop()` qui chiude l'unica rotta dello stack e lascia un
       * `Navigator` vuoto — cioè uno schermo nero che ha tutta l'aria di un
       * crash, tanto che è così che è stato segnalato.
       *
       * ⚠️ Invalidare basta e avanza: `PortaDelleChiavi` rilegge lo stato,
       * trova `pronto` e disegna la chat. La navigazione la fa il cambio di
       * stato, non un comando.
       */
      ref.invalidate(statoChiaviProvider);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _errore = e.toString();
          _inCorso = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Password di recupero'),
        // ⚠️ Niente pulsante «indietro»: senza questa password la chat non
        // funziona, e lasciarla saltare significherebbe un account a metà.
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          Text(
            'I tuoi messaggi sono cifrati',
            style: testo.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Quello che scrivi al tuo trainer viene chiuso a chiave sul tuo '
            'telefono e riaperto solo sul suo. Nessun altro può leggerlo: '
            'né la tua palestra, né noi.',
            style: testo.bodyMedium,
          ),
          const SizedBox(height: Gap.lg),
          Text(
            'Questa password è la tua chiave',
            style: testo.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Ti servirà quando cambierai telefono. Puoi cambiarla quando vuoi, '
            'ma se la dimentichi non possiamo recuperarla per te — e senza, i '
            'messaggi e le schede ricevute non si riaprono più.',
            style: testo.bodyMedium,
          ),
          const SizedBox(height: Gap.lg),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'Password di recupero',
              helperText: 'Almeno $lunghezzaMinima caratteri',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _conferma,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Ripetila',
              errorText: _conferma.text.isNotEmpty &&
                      _conferma.text != _password.text
                  ? 'Le due password non coincidono'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.md),
          CheckboxListTile(
            value: _hoCapito,
            onChanged: (v) => setState(() => _hoCapito = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Ho capito che se dimentico questa password nessuno può '
              'recuperare i miei messaggi.',
            ),
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
            onPressed: _valida && !_inCorso ? _salva : null,
            child: _inCorso
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Crea la password'),
          ),
          const SizedBox(height: Gap.md),
          Text(
            'Suggerimento: tre parole che ti dicono qualcosa, attaccate. '
            'Sono più difficili da indovinare di «Password1!» e molto più '
            'facili da ricordare.',
            style: testo.bodySmall,
          ),
        ],
      ),
    );
  }
}
