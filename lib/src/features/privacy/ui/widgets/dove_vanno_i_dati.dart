import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../consensi_controller.dart';

/// Dove finisce ogni dato — 3b-P.10.1, 22/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// Il committente: *«Deve avere una serie di cards che dettagliano esattamente
/// quali dati prendiamo, quali salviamo sul server e quali inviamo all'AI (se
/// l'AI è attiva)»*.
///
/// ── 🚨 Questo non è testo di interfaccia: è un'informativa ───────────────
///
/// ⛔ **Ogni riga qui dentro è una dichiarazione**, e se dice una cosa diversa
/// da quello che il codice fa davvero è una dichiarazione **falsa** — con la
/// differenza che questa la legge l'utente, mentre `informativa_privacy.md` no.
///
/// 🚨 Quando queste card e i documenti divergono, **vince questa**: è quella su
/// cui una persona decide. Quindi si aggiornano tutti e tre insieme —
/// `memory/informativa_privacy.md`, `memory/registro_trattamenti.md` e questa.
///
/// ⚠️ **Verificato contro il codice il 22/08/2026**, non scritto a memoria:
/// `archivio_salute.dart` per quello che resta qui, `SettimanaPerIlConsiglio` e
/// `AiController::RECUPERO` per quello che parte, `ConsentController` per i
/// consensi che lo governano.
///
/// ── 💡 Tre card e non un elenco unico ────────────────────────────────────
///
/// La domanda che una persona si fa non è «quali dati raccogliete» ma **«chi
/// li vede»**. ⚠️ Un elenco unico ordinato per tipo di dato costringerebbe a
/// leggere venti righe per rispondere; tre card ordinate per **destinazione**
/// rispondono guardando i titoli.
class DoveVannoIDati extends ConsumerWidget {
  const DoveVannoIDati({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consensi = ref.watch(consensiProvider).valueOrNull;

    /*
     * 🚨 **Due consensi diversi, e la differenza conta.**
     *
     * | | |
     * |---|---|
     * | `ai` | l'AI in generale: consiglio, stime dal testo e dalle foto |
     * | `recupero` (`sleep_ai_consent_at`) | i dati di salute **dentro** il consiglio — un consenso **a parte**, come vuole l'art. 7 |
     *
     * ⛔ Chi ha detto sì all'AI ma non al secondo riceve il consiglio **senza**
     * sonno, HRV, battito e allenamenti: il server li scarta prima del prompt
     * (`AiController::recuperoDallApp`).
     */
    final aiAttiva = consensi?.ai != null;
    final saluteAllAi = consensi?.recupero != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dove vanno i tuoi dati',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Gap.sm),

        const _Card(
          icona: Icons.phone_android_rounded,
          titolo: 'Restano su questo telefono',
          sottotitolo:
              'Non partono mai da soli. Se disinstalli l\'app spariscono con '
              'lei: l\'unica copia è quella di sicurezza che fai tu.',
          voci: [
            'Sonno, fasi e risvegli',
            'Variabilità cardiaca e battito a riposo',
            'Calorie bruciate con l\'attività',
            'Allenamenti, sedute e serie',
            'Peso e misure del corpo',
            'Foto dei progressi',
            'Le tue preferenze dell\'app',
          ],
        ),

        const SizedBox(height: Gap.md),

        const _Card(
          icona: Icons.cloud_outlined,
          titolo: 'Stanno sui nostri server',
          sottotitolo:
              'Servono a farli funzionare fra più dispositivi e con il tuo '
              'trainer. La tua palestra vede quello che riguarda il tuo '
              'percorso — mai i messaggi che scambi con il trainer.',
          voci: [
            'Account, email e accessi',
            'Il tuo profilo: sesso, età, altezza, obiettivo',
            'Il diario alimentare e i pasti',
            'Le schede e i piani che ti assegna il trainer',
            'I messaggi con il tuo trainer',
          ],
        ),

        const SizedBox(height: Gap.md),

        /*
         * ⚠️ **La terza card cambia con i consensi, e non sparisce mai.**
         *
         * 🚨 Nasconderla a chi ha l'AI spenta sarebbe la scelta sbagliata: chi
         * sta decidendo se accenderla è **esattamente** la persona che deve
         * poter leggere cosa succederebbe. 💡 Quindi resta, e dice in che
         * stato si trova.
         */
        _Card(
          icona: Icons.auto_awesome_outlined,
          titolo: aiAttiva
              ? 'Vanno all\'intelligenza artificiale'
              : 'Andrebbero all\'intelligenza artificiale',
          sottotitolo: aiAttiva
              ? 'Solo quando serve una risposta, e solo quello che serve a '
                    'quella risposta. Niente nome, niente email, niente foto '
                    'del profilo.'
              : 'L\'AI è spenta: adesso non parte niente. Se la accendi qui '
                    'sotto, partirebbe questo — e solo quando serve una '
                    'risposta.',
          voci: [
            'Quello che scrivi per farti stimare un alimento',
            'Le foto dei pasti, se le usi per la stima',
            'Il diario del giorno e il tuo obiettivo, per il consiglio',
            if (saluteAllAi)
              'Sonno, HRV, battito e allenamenti della settimana'
            else
              'Sonno e recupero NO: è un consenso a parte, e non l\'hai dato',
          ],
          spento: !aiAttiva,
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icona,
    required this.titolo,
    required this.sottotitolo,
    required this.voci,
    this.spento = false,
  });

  final IconData icona;
  final String titolo;
  final String sottotitolo;
  final List<String> voci;

  /// 💡 Smorzata quando descrive qualcosa che **non sta succedendo**: la card
  /// dell'AI spenta parla al condizionale, e il colore lo dice prima del testo.
  final bool spento;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tinta = spento
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icona, color: tinta),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    titolo,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: Gap.xs),

            Text(
              sottotitolo,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: Gap.sm),

            for (final voce in voci)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: Gap.sm),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: tinta,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(voce, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
