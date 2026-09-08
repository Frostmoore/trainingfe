import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../privacy/consensi_controller.dart';
import '../../../privacy/ui/widgets/presa_d_atto_ai.dart';

/// 🎉 «Hai sbloccato le funzionalità IA» — 08/09/2026.
///
/// ══ 📌 QUANDO COMPARE ═════════════════════════════════════════════════════
///
/// Il committente: *«quando si finalizza il pagamento di un abbonamento, si
/// deve aprire una modale…»*.
///
/// 🚨 **Il momento non è «dopo aver toccato paga».** Il pagamento avviene su
/// Stripe, nel browser: `apriIlPagamento()` torna quando il browser si è
/// **aperto**. 💡 Il segnale vero è il **rientro nell'app** con `abbonato`
/// passato da `false` a `true` — vedi `RicontrolloAlRientro`, che è l'unico
/// posto in cui quel passaggio si vede.
///
/// ══ ⚖️ PERCHÉ NON È UN «GRAZIE, BUON DIVERTIMENTO» ════════════════════════
///
/// ⛔ **L'abbonamento non è il consenso**, e questo è il punto legale di tutta
/// la modale. Pagare compra l'accesso a una funzione; mandare i propri dati a
/// un modello negli Stati Uniti è un **trattamento** che richiede il consenso
/// esplicito (art. 9(2)(a) e capo V per il trasferimento).
///
/// 🚨 Dedurre il secondo dal primo sarebbe il difetto più grave possibile qui:
/// chi paga *si aspetta* che tutto funzioni, e un'app che accendesse l'AI da
/// sola sarebbe formalmente in regola con il contratto e **fuori legge** sul
/// GDPR. ⚠️ Per questo l'interruttore parte **spento** se il consenso non c'era,
/// e la modale si può chiudere senza accenderlo: l'abbonamento resta, l'AI no.
///
/// 💡 E se il consenso c'era già, l'interruttore è **acceso e spegnibile**:
/// 📌 *«l'utente deve poterlo mettere su off. In tal caso, naturalmente, l'ai
/// non dovrà funzionare»*. Spegnendolo qui l'AI si spegne davvero — è lo stesso
/// `cambiaConsensoProvider` della schermata Privacy, non una copia.
class HaiSbloccatoLAi extends ConsumerStatefulWidget {
  const HaiSbloccatoLAi({super.key});

  /// La documentazione di Anthropic sulla gestione dei dati.
  ///
  /// ⚠️ **Un indirizzo, non una descrizione**: 📌 *«link con la documentazione
  /// di claude sulla gestione dei dati»*. 🚨 Se un giorno cambia, cambia **qui**
  /// e in `informativa_privacy.md` — sono i due posti in cui è scritto.
  static final documentazione = Uri.parse(
    'https://www.anthropic.com/legal/privacy',
  );

  /// Il `context` e' facoltativo: senza, si usa il navigatore dell'app.
  ///
  /// == PERCHE' IL RIPIEGO E' LA CHIAVE GLOBALE ==
  ///
  /// Chi la chiama dal `builder` di `MaterialApp` -- il ricontrollo
  /// dell'abbonamento -- NON ha un `Navigator` sopra di se', e passando il
  /// proprio `context` otteneva "a context that does not include a Navigator".
  ///
  /// E l'eccezione partiva dentro un `addPostFrameCallback`: nessuna schermata
  /// rossa, nessun blocco, solo una riga in un log che nessuno guardava. La
  /// finestra semplicemente non usciva, e il codice si leggeva giusto.
  static Future<void> mostra([BuildContext? context]) => showModalBottomSheet(
    context: context ?? chiaveDelNavigatore.currentContext!,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const HaiSbloccatoLAi(),
  );

  @override
  ConsumerState<HaiSbloccatoLAi> createState() => _HaiSbloccatoLAiState();
}

class _HaiSbloccatoLAiState extends ConsumerState<HaiSbloccatoLAi> {
  bool _inCorso = false;

  Future<void> _cambia(bool acceso) async {
    /*
     * ⚖️ **La presa d'atto viene prima, anche qui.** È la stessa condizione
     * della schermata Privacy: accendere l'AI senza averla letta scriverebbe
     * un consenso su un testo che nessuno ha visto.
     *
     * 💡 Solo in accensione — spegnere non richiede di leggere niente, e
     * chiedere una conferma a chi revoca sarebbe un ostacolo alla revoca, che
     * l'art. 7(3) vieta.
     */
    if (acceso) {
      final accettata = await chiediLaPresaDAtto(context);

      if (!accettata) return;
    }

    setState(() => _inCorso = true);

    try {
      await ref.read(cambiaConsensoProvider)('ai', acceso, presaDAtto: acceso);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Non ha funzionato: $e')));
      }
    } finally {
      ref.invalidate(consensiProvider);

      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final consensi = ref.watch(consensiProvider);
    final acceso = consensi.valueOrNull?.aiDato ?? false;

    final corpo = tema.textTheme.bodyMedium;
    final grassetto = corpo?.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.lg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Intestazione(),
            const SizedBox(height: Gap.md),

            /*
             * ⚠️ **`RichText` e non tre `Text` in fila**: il testo va a capo in
             * mezzo alle parti in grassetto, e tre widget affiancati andrebbero
             * a capo solo **fra** di loro — cioè in punti sbagliati.
             */
            Text.rich(
              TextSpan(
                style: corpo,
                children: [
                  const TextSpan(
                    text:
                        'Né il tuo nome né un tuo identificativo arriveranno ',
                  ),
                  TextSpan(text: 'mai', style: grassetto),
                  const TextSpan(
                    text:
                        ' a un modello di IA, ma devi concederci il permesso di '
                        'inviare i tuoi dati (',
                  ),
                  TextSpan(
                    text:
                        'completamente anonimi e impossibili da ricondurre a '
                        'te',
                    style: grassetto,
                  ),
                  const TextSpan(
                    text:
                        ') a un modello residente negli Stati Uniti d\'America '
                        '(Claude, di Anthropic PBC, che ne farà l\'uso '
                        'documentato nelle sue policy: ',
                  ),
                  TextSpan(
                    text: 'come Anthropic tratta i dati',
                    style: corpo?.copyWith(
                      color: tema.colorScheme.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: tema.colorScheme.primary,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(
                        HaiSbloccatoLAi.documentazione,
                        mode: LaunchMode.externalApplication,
                      ),
                  ),
                  const TextSpan(
                    text:
                        ') se desideri accedere alle funzionalità suddette.\n\n'
                        'Potrai revocare questo consenso in qualunque momento '
                        'nella sezione «Privacy e consensi» delle impostazioni '
                        'dell\'app.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: Gap.md),

            Card(
              color: tema.colorScheme.surfaceContainerHighest,
              child: SwitchListTile(
                value: acceso,
                onChanged: (_inCorso || consensi.isLoading) ? null : _cambia,
                title: const Text(
                  'Funzionalità IA',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  acceso
                      ? 'Attive. Se lo spegni smettono di funzionare subito.'
                      : 'Spente. L\'abbonamento resta valido lo stesso: '
                            'tutto il resto continua a funzionare.',
                  style: tema.textTheme.bodySmall,
                ),
              ),
            ),

            const SizedBox(height: Gap.sm),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Ho capito'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// L'intestazione rosa che si illumina.
///
/// 📌 *«l'header deve essere di un colore diverso, diciamo rosa, con
/// un'animazione per essere messo in evidenza»*.
///
/// ══ ⚠️ IL ROSA NON VIENE DAL TEMA, COME IL VERDE DEL TASTO «+» ════════════
///
/// 🚨 Su una palestra white-label questo rosa sarà un colore estraneo alla sua
/// tavolozza. 💡 Qui però ha una ragione oltre alla richiesta: questa modale
/// **non parla del prodotto della palestra**, parla di un trasferimento di dati
/// verso gli Stati Uniti. ⛔ Vestirla dei colori del cliente la farebbe
/// sembrare una schermata come le altre, ed è l'unica che non deve.
class _Intestazione extends StatefulWidget {
  const _Intestazione();

  @override
  State<_Intestazione> createState() => _IntestazioneState();
}

class _IntestazioneState extends State<_Intestazione>
    with SingleTickerProviderStateMixin {
  static const rosa = Color(0xFFD81B60);
  static const rosaChiaro = Color(0xFFFF80AB);

  late final AnimationController _controllore;

  @override
  void initState() {
    super.initState();

    /*
     * ⚠️ **Creato qui e non con un `late final` inizializzato al primo uso.**
     * 🚨 È la trappola in cui il banner dell'abbonamento è già caduto l'08/09:
     * se `build` esce prima di toccarlo, l'unico a farlo è `dispose()`, e il
     * controllore nasce chiedendo un `vsync` a uno `State` già staccato.
     */
    _controllore = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
  }

  @override
  void dispose() {
    _controllore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    // ♿ Chi ha chiesto meno movimento riceve il rosa fermo: il testo non cambia.
    final fermo = MediaQuery.disableAnimationsOf(context);

    if (!fermo && !_controllore.isAnimating) _controllore.repeat();

    final testo = Text.rich(
      TextSpan(
        style: tema.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        children: [
          const TextSpan(text: 'Hai sbloccato le '),
          TextSpan(
            text: 'funzionalità IA',
            style: tema.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const TextSpan(text: ' dell\'app!'),
        ],
      ),
    );

    final dentro = Padding(
      padding: const EdgeInsets.all(Gap.md),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          const SizedBox(width: Gap.md),
          Expanded(child: testo),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(Gap.radius),
      child: fermo
          ? DecoratedBox(
              decoration: const BoxDecoration(color: rosa),
              child: dentro,
            )
          : AnimatedBuilder(
              animation: _controllore,
              child: dentro,
              builder: (context, figlio) => DecoratedBox(
                decoration: BoxDecoration(gradient: _fondo(_controllore.value)),
                child: figlio,
              ),
            ),
    );
  }

  /// 💡 La stessa luce che scorre del banner dell'abbonamento, in rosa: una
  /// banda chiara che attraversa da sinistra a destra.
  ///
  /// ⛔ **Non un'opacità che pulsa**: quella lampeggia, e un lampeggio sopra un
  /// testo che va letto lo rende più difficile da leggere, non più evidente.
  LinearGradient _fondo(double t) {
    // 🚨 Parte fuori dal bordo e finisce fuori: entra da un lato ed esce
    // dall'altro invece di comparire e svanire a metà.
    final centro = -0.3 + t * 1.6;

    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      // ⚠️ `clamp`: `LinearGradient` lancia se le fermate escono da [0, 1] —
      // cioè proprio quando la banda entra ed esce, due volte a giro.
      stops: [
        (centro - 0.28).clamp(0.0, 1.0),
        centro.clamp(0.0, 1.0),
        (centro + 0.28).clamp(0.0, 1.0),
      ],
      colors: const [rosa, rosaChiaro, rosa],
    );
  }
}
