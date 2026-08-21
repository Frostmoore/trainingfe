import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../dashboard/gettoni_controller.dart';

/// Dove si attiva l'assistente — 3b-O.3.1, 21/08/2026.
///
/// ══ 🚨 È UN MOCK, E DEVE ESSERE OVVIO CHE LO È ════════════════════════════
///
/// 📌 Il committente: *«per la schermata di acquisto sì, creala per ora mock poi
/// ci attacchiamo stripe per davvero quando l'abbiamo migrato sul dominio
/// vero»*.
///
/// ⚠️ **Un mock che sembra vero è la cosa più pericolosa che si possa
/// pubblicare**: qualcuno tocca «Acquista», non succede niente, e crede di aver
/// pagato. 🚨 Per questo qui non c'è **nessun pulsante che finge**: c'è un
/// avviso in cima che dice che i pagamenti non sono attivi, e i pulsanti sono
/// **disabilitati**.
///
/// 💡 Quando Stripe sarà collegato, si toglie [inArrivo] e si accende
/// `_Piano.onTap`. I prezzi e i tagli restano quelli: vengono da
/// `PlanSeeder::CHIAMATE` e da `STIMA-COSTI-AI.md`, non sono inventati qui.
///
/// ⛔ **Non aggiungere un campo carta, nemmeno finto.** Un modulo che chiede un
/// numero di carta e non lo usa è la definizione di ciò che un'app non deve
/// fare — e non c'è nessun motivo per averlo prima che il pagamento esista.
class SchermataAcquisti extends ConsumerWidget {
  const SchermataAcquisti({super.key});

  /// 🚨 L'interruttore che tiene onesta questa schermata finché il pagamento
  /// non c'è. Si toglie **insieme** al collegamento con Stripe, non prima.
  static const inArrivo = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final gettoni = ref.watch(gettoniProvider).valueOrNull;

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Attiva l\'assistente'),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          if (inArrivo) ...[
            Card(
              color: tema.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.construction_rounded,
                      color: tema.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        'I pagamenti non sono ancora attivi. Questa pagina '
                        'mostra cosa comprenderà l\'abbonamento: nessun '
                        'pulsante qui addebita niente.',
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: tema.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
          ],

          if (gettoni != null && gettoni.disponibili != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Row(
                  children: [
                    Icon(Icons.toll_rounded, color: tema.colorScheme.primary),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        'Hai ${gettoni.disponibili} gettoni',
                        style: tema.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
          ],

          Text(
            'Cosa fa l\'assistente',
            style: tema.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Gap.sm),

          /*
           * 💡 **Prima cosa fa, poi quanto costa.** Chi arriva qui ci arriva
           * perché una funzione gli è stata negata: sapere *cosa* riavrebbe
           * viene prima del prezzo. ⚠️ Una pagina che apre con il listino
           * chiede di decidere prima di aver capito.
           */
          const _CosaFa(
            icona: Icons.restaurant_rounded,
            titolo: 'Il piatto dalla foto o da una frase',
            testo:
                'Scrivi «due uova e una fetta di pane» o fotografi il piatto, '
                'e le calorie e i macro entrano nel diario.',
          ),
          const _CosaFa(
            icona: Icons.auto_awesome_outlined,
            titolo: 'Il consiglio del giorno',
            testo:
                'Ogni giorno una riga costruita su quello che hai mangiato, '
                'come hai dormito e come ti sei allenato.',
          ),
          const _CosaFa(
            icona: Icons.picture_as_pdf_outlined,
            titolo: 'Il piano alimentare da PDF',
            testo:
                'Il piano del tuo nutrizionista diventa un piano dentro '
                'l\'app, da rivedere riga per riga.',
          ),

          const SizedBox(height: Gap.lg),

          Text(
            'I piani',
            style: tema.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Gap.sm),

          /*
           * 🚨 I numeri **non sono inventati qui**: 400 chiamate al mese di cui
           * 40 con foto sono quelle di `PlanSeeder::CHIAMATE`, ricavate dai
           * consumi misurati in `STIMA-COSTI-AI.md`. ⚠️ Scriverne altri in
           * questa schermata vorrebbe dire due listini che divergono.
           */
          const _Piano(
            nome: 'Assistente',
            prezzo: '—',
            righe: [
              '400 richieste al mese',
              'di cui 40 con foto',
              'consiglio del giorno compreso',
            ],
          ),

          const SizedBox(height: Gap.md),

          const _Piano(
            nome: 'Gettoni',
            prezzo: '—',
            righe: [
              'si comprano una volta e restano',
              'un gettone = una richiesta',
              'servono quando il piano è finito',
            ],
          ),

          const SizedBox(height: Gap.xl),
        ],
      ),
    );
  }
}

class _CosaFa extends StatelessWidget {
  const _CosaFa({
    required this.icona,
    required this.titolo,
    required this.testo,
  });

  final IconData icona;
  final String titolo;
  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icona, size: 20, color: tema.colorScheme.primary),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titolo,
                  style: tema.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  testo,
                  style: tema.textTheme.bodySmall?.copyWith(height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Piano extends StatelessWidget {
  const _Piano({required this.nome, required this.prezzo, required this.righe});

  final String nome;
  final String prezzo;
  final List<String> righe;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

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
                    nome,
                    style: tema.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  prezzo,
                  style: tema.textTheme.titleMedium?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: Gap.sm),

            for (final r in righe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: tema.colorScheme.primary,
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(child: Text(r, style: tema.textTheme.bodySmall)),
                  ],
                ),
              ),

            const SizedBox(height: Gap.sm),

            /*
             * 🚨 **Disabilitato, non nascosto.** Nascondere il pulsante
             * lascerebbe una pagina che descrive qualcosa senza dire come si
             * ottiene; disabilitarlo dice **che si potrà**, e che adesso no.
             *
             * ⚠️ E non fa niente: un mock che finge un acquisto è il modo di
             * far credere a qualcuno di aver pagato.
             */
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: SchermataAcquisti.inArrivo ? null : () {},
                child: const Text(
                  SchermataAcquisti.inArrivo ? 'Presto disponibile' : 'Attiva',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
