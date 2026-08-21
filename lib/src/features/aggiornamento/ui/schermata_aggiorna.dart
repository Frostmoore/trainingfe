import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../aggiornamento_controller.dart';

/// 🔒 Questa versione dell'app non parla più con il server — FASE 10.5.
///
/// ══ ⚠️ È UN VICOLO CIECO, E LO DICHIARA ═══════════════════════════════════
///
/// Non c'è nessun «continua lo stesso». 🚨 Se il server dice che questa versione
/// non parla più la sua lingua, continuare vuol dire mostrare **dati sbagliati**
/// — che è peggio di non mostrarne.
///
/// ── 🚨 E deve dire che i dati non si perdono ──────────────────────────────
///
/// Chi legge «l'app è bloccata» pensa a sonno, peso, allenamenti e foto — che
/// stanno **solo su questo telefono** (D9). ⚠️ Aggiornare dallo store **non li
/// tocca**, e va scritto qui: senza, qualcuno disinstalla per «risolvere» e li
/// perde davvero. 💡 È il tipo di danno che il blocco stesso causerebbe se non
/// spiegasse.
class SchermataAggiorna extends ConsumerStatefulWidget {
  const SchermataAggiorna({super.key});

  @override
  ConsumerState<SchermataAggiorna> createState() => _SchermataAggiornaState();
}

class _SchermataAggiornaState extends ConsumerState<SchermataAggiorna> {
  bool _inCorso = false;

  /// L'indirizzo dello store, se il 426 non l'ha portato.
  String? _storeDiRipiego;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _recuperaLoStore());
  }

  /// ⚠️ **Il link allo store non può mancare: è l'unica azione di questa
  /// schermata.** Senza, la persona legge «aggiorna» e non ha da nessuna parte
  /// per andare — cioè il blocco diventa un vicolo cieco davvero.
  ///
  /// 🚨 Il 426 lo porta, ma **solo se il corpo della risposta si è potuto
  /// leggere**: una richiesta che scarica byte grezzi (`scaricaByte`) o una
  /// risposta che per qualunque ragione non è JSON lascerebbe `store` a `null`,
  /// e non c'è modo di saperlo prima. 💡 `GET /versione` sta **fuori dal
  /// cancello** e lo porta sempre: è la rete di sicurezza.
  Future<void> _recuperaLoStore() async {
    if (ref.read(aggiornamentoProvider).store != null) return;

    try {
      final dati = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/versione');

      final store = dati['store']?.toString();

      if (mounted && store != null && store.isNotEmpty) {
        setState(() => _storeDiRipiego = store);
      }
    } on Object catch (e) {
      // ⚠️ Muto: senza rete non si può fare niente, e dirlo qui aggiungerebbe
      // un errore a una schermata che già sta dando una brutta notizia.
      debugPrint('SchermataAggiorna: lo store non si recupera — $e');
    }
  }

  /// Richiede il verdetto al server.
  ///
  /// 🚨 Passa da `GET /versione`, che sta **fuori dal cancello**: se fosse
  /// dietro, l'app bloccata non potrebbe nemmeno chiedere «sono ancora
  /// vecchia?» e questo pulsante non avrebbe niente da interrogare.
  ///
  /// 💡 Serve quando il blocco è stato **un errore nostro** — un minimo alzato
  /// per sbaglio. Senza, per toglierlo servirebbe un'altra pubblicazione.
  Future<void> _riprova() async {
    setState(() => _inCorso = true);

    try {
      await ref.read(apiClientProvider).get<Map<String, dynamic>>('/versione');

      /*
       * ⚠️ Se `/versione` risponde **senza** un 426, vuol dire che il server non
       * ci sta più bloccando: si esce. Il verdetto arriverà di nuovo, da solo,
       * alla prima richiesta vera — non serve fidarsi di questa.
       */
      if (mounted) ref.read(aggiornamentoProvider.notifier).sblocca();
    } on Object catch (e) {
      /*
       * 🚨 **Si sbuccia con `unwrapError`, non con `on ...Exception`.**
       *
       * ⚠️ Quello che arriva da `dio` è una `DioException` che **contiene** la
       * nostra: un `on AppDaAggiornareException` non la prenderebbe mai, e il
       * ramo finirebbe nel messaggio d'errore generico. 💡 L'ha trovato un test,
       * ed è il tipo di svista che dal vivo si sarebbe vista come «il pulsante
       * Riprova dà sempre errore».
       */
      final tradotto = ApiClient.unwrapError(e);

      if (tradotto is AppDaAggiornareException) {
        // 💡 Ancora bloccati: si resta qui, senza dire niente di nuovo.
        // Ripetere «sei vecchia» a chi lo sta già leggendo non aggiunge niente.
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tradotto.message)));
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _apriLoStore(String indirizzo) async {
    final uri = Uri.tryParse(indirizzo);

    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final stato = ref.watch(aggiornamentoProvider);
    /*
     * 🚨 **Due sorgenti, e la seconda è nata da un difetto vero.**
     *
     * Il 21/08, con il blocco al primo tentativo su `426`, `stato.store`
     * arrivava **sempre nullo** e il pulsante «Aggiorna» non compariva: lo stack
     * HTTP di Android buttava via il corpo della risposta. ⚠️ Il codice è poi
     * diventato `409` e il corpo arriva, ma il ripiego **resta**: il link allo
     * store è l'unica azione di questa schermata, e una schermata di blocco
     * senza via d'uscita è peggio del problema che risolve.
     */
    final store = stato.store ?? _storeDiRipiego;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.system_update_rounded,
                size: 64,
                color: tema.colorScheme.primary,
              ),

              const SizedBox(height: Gap.lg),

              Text(
                'App da aggiornare',
                style: tema.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: Gap.sm),

              Text(
                'Questa versione non è più compatibile con il servizio. '
                'Aggiornala per continuare.',
                style: tema.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: Gap.lg),

              /*
               * 🚨 **La frase che evita il danno peggiore.** Chi legge «app
               * bloccata» pensa che i suoi dati siano in ostaggio, e la prima
               * cosa che viene in mente è disinstallare — che è esattamente
               * l'unica azione che li cancella davvero.
               */
              Card(
                margin: EdgeInsets.zero,
                color: tema.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 20,
                        color: tema.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          'I tuoi dati restano dove sono. Aggiornando dallo '
                          'store non si perde niente: diario, peso, sonno e '
                          'allenamenti sono su questo telefono e ci restano.\n'
                          'Non disinstallare l\'app.',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: Gap.lg),

              if (store != null)
                FilledButton.icon(
                  onPressed: () => _apriLoStore(store),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Aggiorna'),
                ),

              const SizedBox(height: Gap.sm),

              TextButton(
                onPressed: _inCorso ? null : _riprova,
                child: Text(_inCorso ? 'Controllo…' : 'Ho aggiornato, riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
