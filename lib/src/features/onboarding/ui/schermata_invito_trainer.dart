import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../../auth/auth_controller.dart';
import '../invito_del_trainer_controller.dart';

/// 🆕 La pagina che si apre toccando l'invito di un **trainer** — F6.2,
/// 17/09/2026.
///
/// ══ ⛔ PERCHE' NASCE OGGI ══════════════════════════════════════════════════
///
/// 🚨 **Questo giro viveva sul server senza un cliente.** La pagina web diceva
/// *«apri l'app e tocca "Ho un invito"»*, e **quel pulsante non esisteva**.
/// ⚠️ Trovato cercando dove mettere la modale della sovrapposizione: non c'era
/// nessuna schermata dove metterla.
///
/// ══ 🚨 E NON E' L'INVITO DI UNA PALESTRA ══════════════════════════════════
///
/// Quello sposta una persona dentro un'**organizzazione**, e la veste dei suoi
/// colori. ⛔ Questo crea un legame fra **due persone**: nessun marchio da
/// adottare, nessun trasloco di dati, nessun colore da cambiare.
///
/// 💡 Per questo la pagina è più sobria: chi invita ha un nome, non un logo.
class SchermataInvitoTrainer extends ConsumerWidget {
  const SchermataInvitoTrainer({required this.token, super.key});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invito = ref.watch(invitoDelTrainerProvider(token));

    return invito.when(
      loading: () => const Scaffold(body: LoadingState()),

      /*
       * ⛔ **Un invito non valido non dice PERCHE'**, e qui l'app non potrebbe
       * saperlo nemmeno volendo: il server risponde lo stesso 404 a scaduto,
       * revocato, già usato e mai esistito — apposta, perché distinguerli
       * darebbe a chiunque un modo di sapere quali token sono buoni.
       */
      error: (e, _) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: EmptyState(
            icon: Icons.link_off_rounded,
            title: 'Questo invito non è più valido',
            message:
                'Può essere scaduto, o già usato da qualcun altro. '
                'Chiedine uno nuovo al tuo trainer.',
            action: FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Va bene'),
            ),
          ),
        ),
      ),

      data: (dati) => _Pagina(token: token, invito: dati),
    );
  }
}

class _Pagina extends ConsumerStatefulWidget {
  const _Pagina({required this.token, required this.invito});

  final String token;
  final InvitoDelTrainer invito;

  @override
  ConsumerState<_Pagina> createState() => _PaginaState();
}

class _PaginaState extends ConsumerState<_Pagina> {
  bool _inCorso = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final chi = widget.invito.trainer ?? 'Un trainer';
    final serveUnAccount = !ref.watch(sessioneAttivaProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Gap.lg),
                children: [
                  const SizedBox(height: Gap.xl),
                  Icon(
                    Icons.handshake_outlined,
                    size: 56,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(height: Gap.md),
                  Text(
                    '$chi ti ha invitato',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Accettando, $chi diventa il tuo trainer.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Gap.lg),

                  /*
                   * 💡 **Cosa cambia davvero**, e sono tre cose precise. ⚠️ Non
                   * è una lista di vantaggi: è quello che quella persona vedrà
                   * succedere, e che ha il diritto di sapere prima.
                   */
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(Gap.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Riga(
                            icona: Icons.fitness_center_rounded,
                            titolo: 'Ti manda le schede',
                            testo:
                                'Arrivano sul telefono e le usi in palestra, '
                                'anche senza rete.',
                          ),
                          _Riga(
                            icona: Icons.chat_bubble_outline_rounded,
                            titolo: 'Potete scrivervi senza limiti',
                            testo:
                                'I messaggi li leggete solo voi due: nemmeno '
                                'noi possiamo aprirli.',
                          ),
                          _Riga(
                            icona: Icons.visibility_outlined,
                            titolo: 'Vede i tuoi allenamenti',
                            testo:
                                'Gli serve per scriverti le schede giuste. '
                                'Il diario di quello che mangi resta tuo.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                children: [
                  if (serveUnAccount) ...[
                    Text(
                      "Per accettare serve il tuo account. L'invito ti aspetta "
                      'qui.',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Gap.sm),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _inCorso
                          ? null
                          : (serveUnAccount ? _accedi : _accetta),
                      child: _inCorso
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(serveUnAccount ? 'Accedi' : 'Accetto'),
                    ),
                  ),

                  if (serveUnAccount) ...[
                    const SizedBox(height: Gap.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _inCorso ? null : _registrati,
                        child: const Text('Non ho ancora un account'),
                      ),
                    ),
                  ],

                  const SizedBox(height: Gap.sm),
                  TextButton(
                    onPressed: _inCorso
                        ? null
                        : () => context.go(AppRoutes.home),
                    child: const Text('No, grazie'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _accedi() =>
      context.push(AppRoutes.accediPerInvitoTrainer(widget.token));

  void _registrati() =>
      context.push(AppRoutes.registratiPerInvitoTrainer(widget.token));

  /// Accetta, e se il server dice che c'è già un trainer, **chiede**.
  Future<void> _accetta({bool affianco = false}) async {
    setState(() => _inCorso = true);

    try {
      final nome = await ref
          .read(rispostaAlTrainerProvider)
          .accetta(widget.token, affianco: affianco);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ora ti segue ${nome ?? 'il tuo trainer'}.')),
      );

      context.go(AppRoutes.home);
    } on Object catch (e) {
      if (!mounted) return;

      setState(() => _inCorso = false);

      /*
       * 🚨 **Si riconosce DOPO `unwrapError`, non con un `on <Tipo> catch`.**
       *
       * ⛔ Il client rilancia l'errore grezzo del trasporto: la traduzione in
       * una delle nostre classi avviene **qui**, non prima. ⚠️ Un
       * `on TiSegueGiaQualcunoException catch` non prende mai niente, e
       * l'errore finisce nel ramo generico — dove la frase e' pure giusta,
       * quindi sembra funzionare.
       *
       * 🔬 Visto sull'emulatore: usciva il messaggio *«non riesco a farlo
       * perche' gia' ti segue Giro Quattordici»* invece della domanda. 💡 E'
       * lo stesso modo in cui `miei_utenti_screen.dart` riconosce
       * l'abbonamento scaduto.
       */
      final errore = ApiClient.unwrapError(e);

      if (errore is TiSegueGiaQualcunoException) {
        await _chiediSeAffiancare(errore.chiTiSegue);

        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Non sono riuscito a completare. ${errore.message}'),
        ),
      );
    }
  }

  /// 🚨 **La modale della sovrapposizione** — AH.1-ter.4.
  ///
  /// 📌 Dal piano: *«con "Lascia com'è" in evidenza»*, ed è il verso giusto: chi
  /// ha già un trainer non è arrivato qui per cambiarlo, e la scelta che non
  /// cambia niente deve costare meno di quella che cambia.
  ///
  /// ⚠️ **Dice cosa comporta davvero**, e sono tre cose: tutti e due vedranno
  /// gli allenamenti, tutti e due scriveranno, e il posto lo occupano in due.
  /// 💡 Senza, «vuoi affiancare?» sarebbe una domanda a cui non si può
  /// rispondere.
  Future<void> _chiediSeAffiancare(String chiTiSegue) async {
    final chi = chiTiSegue.isEmpty ? 'un altro trainer' : chiTiSegue;
    final nuovo = widget.invito.trainer ?? 'questo trainer';

    final affianco = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Ti segue già $chi'),
        content: Text(
          'Se accetti, ti seguiranno in due: $chi e $nuovo.\n\n'
          'Vedranno tutti e due i tuoi allenamenti e potrete scrivervi con '
          'tutti e due. Puoi chiudere un rapporto quando vuoi.',
        ),
        actions: [
          /*
           * ⛔ **«Lascia com'è» è il tasto pieno**, e non è una svista: chi è
           * arrivato qui per sbaglio, o ci ha ripensato, deve trovare la via
           * d'uscita sotto il dito. 💡 Aggiungere un secondo trainer è la
           * scelta che cambia qualcosa, e le scelte che cambiano qualcosa si
           * fanno apposta.
           */
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text('Seguimi anche tu, $nuovo'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text("Lascia com'è"),
          ),
        ],
      ),
    );

    if (affianco != true || !mounted) return;

    await _accetta(affianco: true);
  }
}

class _Riga extends StatelessWidget {
  const _Riga({required this.icona, required this.titolo, required this.testo});

  final IconData icona;
  final String titolo;
  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icona, color: tema.colorScheme.primary),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titolo,
                  style: tema.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  testo,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
