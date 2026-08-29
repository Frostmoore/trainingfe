import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../../auth/auth_controller.dart';
import '../branding_controller.dart';
import '../data/invito_in_palestra.dart';
import '../invito_controller.dart';

/// La pagina che si apre toccando un link d'invito — 3b-V.2.5.
///
/// ══ 📌 LA RICHIESTA, PUNTO PER PUNTO ══════════════════════════════════════
///
/// *«a chi ci clicca si deve aprire l'app in una pagina con la descrizione della
/// palestra, il logo, i colori, un messaggio di congratulazioni, le cose a cui
/// avrà accesso e due tasti, uno per accettare e uno per rifiutare»*.
///
/// | Chiesto | Dove sta |
/// |---|---|
/// | il logo | [_Intestazione] |
/// | i colori | 🚨 tutta la pagina, vedi sotto |
/// | congratulazioni | [_Intestazione] |
/// | la descrizione | [_Intestazione] |
/// | le cose a cui avrà accesso | [_CosaOttieni] — **le manda il server** |
/// | due tasti | [_DueTasti] |
///
/// ══ 🚨 I COLORI SONO QUELLI DELLA PALESTRA, NON QUELLI DELL'APP ═══════════
///
/// ⚠️ È l'unico momento in cui questa cosa è vera **prima** di entrarci: la
/// palestra si sta presentando, e presentarsi coi colori di qualcun altro è il
/// contrario di quello che serve. 💡 Il tema si costruisce qui, sopra la
/// schermata, e vale solo per questa pagina.
///
/// ══ ⛔ E NON SI ENTRA PER SBAGLIO ═════════════════════════════════════════
///
/// Il tasto che accetta **sposta una persona dentro un'organizzazione**, e da
/// lì si esce solo parlando con loro. 🚨 Per questo non c'è nessun gesto rapido,
/// nessuno scorrimento, nessun «tocca per continuare»: due tasti dichiarati, e
/// quello che accetta chiede conferma.
class SchermataInvito extends ConsumerWidget {
  const SchermataInvito({required this.token, super.key});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invito = ref.watch(invitoProvider(token));

    return invito.when(
      loading: () => const Scaffold(body: LoadingState()),

      /*
       * ⛔ **Un invito non valido non dice PERCHÉ**, e qui l'app non potrebbe
       * saperlo nemmeno volendo: il server risponde lo stesso 404 a scaduto,
       * revocato, già usato e mai esistito, apposta — distinguerli darebbe a
       * chiunque un modo di sapere quali token sono buoni.
       *
       * 💡 Quindi si dice l'unica cosa vera e utile: chiedine un altro.
       */
      /*
       * ⚠️ **Niente intestazione, nemmeno qui.** `IntestazioneApp` porta i
       * colori della palestra, il saldo dei gettoni e il profilo: tre cose che
       * non esistono per chi sta guardando un invito e non è ancora nessuno.
       * 💡 La via d'uscita è il tasto, che basta.
       */
      error: (e, _) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: EmptyState(
            icon: Icons.link_off_rounded,
            title: 'Questo invito non è più valido',
            message:
                'Può essere scaduto, o già usato da qualcun altro. '
                'Chiedine uno nuovo alla palestra.',
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
  final InvitoInPalestra invito;

  @override
  ConsumerState<_Pagina> createState() => _PaginaState();
}

class _PaginaState extends ConsumerState<_Pagina> {
  bool _inCorso = false;

  @override
  Widget build(BuildContext context) {
    final marchio = widget.invito.palestra;

    /*
     * 🚨 **Il tema della PALESTRA, per questa pagina sola.**
     *
     * ⚠️ Non si tocca il tema dell'app: se la persona rifiuta — o l'invito non
     * va a buon fine — l'app deve restare com'era. Cambiare il tema globale per
     * mostrare un'anteprima vorrebbe dire vestirsi dei colori di una palestra
     * in cui non si è entrati.
     */
    final tema = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.dark(marchio)
        : AppTheme.light(marchio);

    return Theme(
      data: tema,
      child: Scaffold(
        backgroundColor: tema.colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(Gap.lg),
                  children: [
                    _Intestazione(invito: widget.invito),
                    const SizedBox(height: Gap.lg),
                    _CosaOttieni(righe: widget.invito.cosaOttieni),
                  ],
                ),
              ),

              _DueTasti(
                inCorso: _inCorso,
                nome: marchio.name,
                onAccetta: _accetta,
                onRifiuta: _rifiuta,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ⚠️ **Chiede conferma**, e non è una gentilezza: accettare sposta la
  /// persona dentro un'organizzazione, e da lì si esce solo parlando con loro.
  Future<void> _accetta() async {
    final marchio = widget.invito.palestra;

    final sicuro = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Entri in ${marchio.name ?? 'questa palestra'}?'),
        content: const Text(
          'I tuoi dati e i tuoi allenamenti si spostano dentro la palestra. '
          'Per uscirne dovrai parlare con loro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Aspetta'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Entro'),
          ),
        ],
      ),
    );

    if (sicuro != true || !mounted) return;

    setState(() => _inCorso = true);

    try {
      final marchioNuovo = await ref
          .read(rispostaAllInvitoProvider)
          .accetta(widget.token);

      // 🏷️ Adesso sì: da questo momento l'app **è** vestita della palestra.
      await ref.read(brandingControllerProvider.notifier).adotta(marchioNuovo);

      // 💡 Il profilo cambia tenant: senza questo, l'app resterebbe con
      // l'utente di prima finché non si riavvia.
      await ref.read(authControllerProvider.notifier).refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Benvenuto in ${marchioNuovo['name'] ?? 'palestra'}!'),
        ),
      );

      context.go(AppRoutes.home);
    } on Object catch (e) {
      if (!mounted) return;

      /*
       * 🚨 **Qui l'errore si mostra**, al contrario del rifiuto: la persona ha
       * chiesto di entrare e non è entrata. ⛔ Un silenzio la lascerebbe a
       * guardare la stessa pagina senza sapere se ha funzionato.
       */
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Non sono riuscito a farti entrare. $e')),
      );
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _rifiuta() async {
    setState(() => _inCorso = true);

    // ⚠️ Non si aspetta un esito da mostrare: il rifiuto è una cortesia verso
    // la palestra, non un'operazione della persona. Vedi `RispostaAllInvito`.
    await ref.read(rispostaAllInvitoProvider).rifiuta(widget.token);

    if (!mounted) return;

    context.go(AppRoutes.home);
  }
}

/// Logo, congratulazioni e descrizione.
class _Intestazione extends StatelessWidget {
  const _Intestazione({required this.invito});

  final InvitoInPalestra invito;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final marchio = invito.palestra;

    return Column(
      children: [
        if (marchio.logoUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              marchio.logoUrl!,
              height: 96,
              // ⚠️ Un logo che non si scarica non deve lasciare un buco né far
              // fallire la pagina: l'invito vale lo stesso.
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        const SizedBox(height: Gap.md),

        /*
         * 🚨 **Le congratulazioni prima del nome, e non viceversa.** È un
         * invito, non una notifica di sistema: la prima riga deve suonare come
         * qualcuno che ti apre la porta.
         */
        Text(
          'Ti hanno invitato!',
          style: tema.textTheme.titleSmall?.copyWith(
            color: tema.colorScheme.primary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: Gap.sm),

        Text(
          marchio.name ?? 'Una palestra',
          style: tema.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),

        if (invito.descrizione != null && invito.descrizione!.isNotEmpty) ...[
          const SizedBox(height: Gap.md),
          Text(
            invito.descrizione!,
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// «Le cose a cui avrà accesso».
class _CosaOttieni extends StatelessWidget {
  const _CosaOttieni({required this.righe});

  final List<VantaggioInPalestra> righe;

  /// 💡 Il server manda **un nome**, non un `IconData`: non può mandare
  /// un'icona di Flutter, e non deve. ⚠️ Una parola che questa versione non
  /// conosce ricade sulla spunta, invece di lasciare un buco.
  static IconData _icona(String nome) => switch (nome) {
    'fitness_center' => Icons.fitness_center_rounded,
    'chat' => Icons.chat_bubble_outline_rounded,
    'restaurant' => Icons.restaurant_rounded,
    'auto_awesome' => Icons.auto_awesome_rounded,
    _ => Icons.check_circle_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    if (righe.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cosa avrai', style: tema.textTheme.titleMedium),
          const SizedBox(height: Gap.md),

          for (final riga in righe)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_icona(riga.icona), color: tema.colorScheme.primary),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(riga.titolo, style: tema.textTheme.titleSmall),
                        Text(
                          riga.dettaglio,
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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

/// I due tasti, e la distanza fra loro.
class _DueTasti extends StatelessWidget {
  const _DueTasti({
    required this.inCorso,
    required this.nome,
    required this.onAccetta,
    required this.onRifiuta,
  });

  final bool inCorso;
  final String? nome;
  final VoidCallback onAccetta;
  final VoidCallback onRifiuta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: inCorso ? null : onAccetta,
              child: inCorso
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Entro in ${nome ?? 'palestra'}'),
            ),
          ),
          const SizedBox(height: Gap.sm),

          /*
           * ⚠️ **Il rifiuto è un `TextButton`, non un secondo tasto pieno.**
           * Due tasti dello stesso peso trasformano una scelta facile in un
           * bivio, e chi è arrivato fin qui di solito vuole entrare. 💡 Ma c'è,
           * è leggibile e non è nascosto in un angolo: dire di no deve costare
           * un tocco, non una ricerca.
           */
          TextButton(
            onPressed: inCorso ? null : onRifiuta,
            child: const Text('No, grazie'),
          ),
        ],
      ),
    );
  }
}
