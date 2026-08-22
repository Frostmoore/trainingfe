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

        /*
         * ══ ✅ VERIFICATO SUL CODICE, NON SCRITTO A MEMORIA — 22/08/2026 ═══
         *
         * 📌 Il committente: *«vedi veramente quali dati restano sul server,
         * quali restano sul telefono e quali inviamo ad Anthropic»*.
         *
         * ⚠️ **Il primo giro era scritto a occhio, e conteneva un errore**: il
         * peso figurava fra i dati del server. 🚨 `storicoCorpoProvider` legge
         * da `archivioSalute.storicoMisure()` — è **locale** dalla fase S5. Sul
         * server resta solo il peso *obiettivo*, che è un campo del profilo.
         *
         * 💡 Le fonti, per chi deve riverificare:
         * · `corpo_controller.dart` → misure locali
         * · `AiController::contestoConsiglio()` → cosa entra nel consiglio
         * · `AiController::RECUPERO` / `SETTIMANA` → le liste bianche
         * · `AnthropicProvider::rawCall()` → cosa parte davvero nella richiesta
         * · `DashboardService::corpo()` → `body` è **solo** il peso obiettivo
         */
        const _Card(
          icona: Icons.phone_android_rounded,
          titolo: 'Restano su questo telefono',
          sottotitolo:
              'Non partono mai da soli. Se disinstalli l\'app spariscono con '
              'lei: l\'unica copia è quella di sicurezza che fai tu.',
          voci: [
            'Sonno: ore, fasi e risvegli',
            'Variabilità cardiaca e battito a riposo',
            'Calorie bruciate con l\'attività',
            'Allenamenti, sedute, serie e ripetizioni',
            'Peso e misure che registri',
            'Foto dei progressi',
            'Le preferenze dell\'app',
            'La chiave che apre i messaggi con il trainer',
          ],
        ),

        const SizedBox(height: Gap.md),

        /*
         * ══ 🚨 «I MESSAGGI CON IL TUO TRAINER» ERA SBAGLIATA ══════════════
         *
         * 📌 Il committente, rileggendo la card: *«i messaggi col trainer dici
         * che restano sul server. Però non dovrebbero: tutto il senso della
         * chat è che sia e2e»*.
         *
         * ✅ **E ha ragione: la chat È cifrata da un capo all'altro**, e la
         * riga di prima metteva le buste cifrate nello stesso elenco del
         * diario e del profilo — che il server legge in chiaro. Vero alla
         * lettera («stanno sui nostri server»), **falso nel significato**: chi
         * la leggeva capiva che i messaggi li possiamo vedere.
         *
         * 💡 Verificato: `busta_messaggio.dart` usa `crypto_box_easy` — X25519
         * per il segreto condiviso, XSalsa20-Poly1305 per cifrare **e
         * autenticare**. ⛔ Non `crypto_box_seal`, di proposito: quella non
         * autentica il mittente, e chiunque possa scrivere sulla tabella
         * `messages` — cioè il nostro server — potrebbe fabbricare un
         * messaggio **a nome del trainer**.
         *
         * 🚨 E i messaggi in chiaro non esistono nemmeno come residuo: la
         * migrazione `create_chat_crypto_tables` **li ha cancellati tutti**
         * prima di aggiungere `nonce` ed `envelope_version`.
         */
        const _Card(
          icona: Icons.cloud_outlined,
          titolo: 'Stanno sui nostri server',
          sottotitolo:
              'Servono a farli funzionare con il tuo trainer e a ritrovarli se '
              'cambi telefono. La tua palestra vede quello che riguarda il tuo '
              'percorso.',
          voci: [
            'Account, email e accessi',
            'Il profilo: sesso, età, altezza, obiettivo e peso da raggiungere',
            'Il diario alimentare, con quello che scrivi negli alimenti',
            'Le schede e i piani che ti assegna il trainer',
            'Acquisti e gettoni',
          ],
        ),

        const SizedBox(height: Gap.md),

        /*
         * ⚠️ **Una card a parte, e non una riga in quella sopra.** I messaggi
         * *transitano* dai nostri server e *non* sono leggibili: metterli in
         * elenco con il diario li fa leggere come la stessa cosa.
         */
        /*
         * ══ ⚠️ IL TONO: «VEDIAMO» SUONAVA COME SORVEGLIANZA ═══════════════
         *
         * 📌 Il committente, rileggendo: *«pare che stai dicendo che andiamo a
         * vedere chi scrive a chi. Non va detta sta cosa, o almeno non così»*.
         *
         * 🚨 **Ed è una critica sul tono, non sui fatti.** «Vediamo CHE vi
         * siete scritti» è vero, ma mette **noi** come soggetto di un verbo di
         * osservazione: descrive qualcuno che guarda. Quello che succede
         * davvero è che una busta, per essere consegnata, deve avere sopra un
         * destinatario e una data.
         *
         * ⛔ **Toglierlo del tutto sarebbe stato peggio**, ed è la scelta che
         * non è stata fatta: sarebbe la «metà comoda della verità» — dire «è
         * cifrata» e tacere che i metadati esistono. È la stessa forma delle
         * cinque frasi false corrette oggi, solo girata dalla parte che ci fa
         * comodo.
         *
         * 💡 La correzione è **cambiare soggetto**: non «cosa guardiamo noi»
         * ma «cosa resta della busta». Il fatto è identico, la frase non
         * descrive più nessuno che osserva.
         */
        const _Card(
          icona: Icons.lock_outline_rounded,
          titolo: 'Passano dai server, ma chiusi',
          sottotitolo:
              'I messaggi con il trainer sono cifrati sul tuo telefono e si '
              'aprono solo sul suo. Noi teniamo la busta e non abbiamo la '
              'chiave.',
          voci: [
            'Il contenuto non lo legge nessuno: né noi, né la tua palestra, '
                'nemmeno quando un amministratore entra al posto tuo',
            'Della busta restano la data e se è stata aperta: servono a '
                'consegnarla e a metterla in ordine',
            'Non possiamo nemmeno scriverne una fingendoci il tuo trainer: la '
                'firma dipende dalla sua chiave, che non abbiamo',
            'La tua chiave privata sta sul telefono. Sul server ce n\'è una '
                'copia chiusa con la tua password di recupero, che non ci '
                'arriva mai: senza quella non la apriamo nemmeno noi',
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
                    'quella risposta.'
              : 'L\'AI è spenta: adesso non parte niente. Se la accendi qui '
                    'sotto, partirebbe questo — e solo quando serve una '
                    'risposta.',
          voci: [
            'Il consiglio del giorno: solo numeri — calorie, macro, obiettivo, '
                'minuti di allenamento, peso da raggiungere. Nessun alimento '
                'per nome',
            if (saluteAllAi)
              'Con il tuo consenso, anche la settimana di sonno, battito e '
                  'allenamenti: ore, minuti e numeri'
            else
              'Sonno e recupero NO: è un consenso a parte, e non l\'hai dato',
            'Quello che scrivi per farti stimare un alimento, come l\'hai '
                'scritto',
            'Le foto dei pasti, se le usi per la stima',
            'Il PDF di una scheda o di un piano, se lo importi',
          ],
          spento: !aiAttiva,
        ),

        const SizedBox(height: Gap.md),

        /*
         * ══ 🚨 LA PARTE PIÙ IMPORTANTE, E LA PIÙ FACILE DA SCRIVERE FALSA ══
         *
         * 📌 Il committente: *«indica chiaramente che i dati che mandiamo ad
         * Anthropic non sono associabili a lui, sono solo numeri senza nessun
         * identificativo»*.
         *
         * ✅ **Sulla prima metà è vero, ed è verificato**: `rawCall()` manda
         * modello, messaggi e prompt di sistema. Niente nome, niente email,
         * niente id dell'account, niente palestra. Non c'è nemmeno il campo
         * `metadata.user_id` che l'API permetterebbe.
         *
         * ⛔ **Sulla seconda metà "solo numeri" non lo è per tutto**, e dirlo
         * senza distinguere sarebbe la terza dichiarazione falsa di oggi:
         *
         * | Cosa parte | È solo numeri? |
         * |---|---|
         * | Consiglio del giorno | ✅ sì — vedi `contestoConsiglio()` |
         * | Settimana di sonno e allenamenti | ✅ sì — liste bianche `SETTIMANA` e `RECUPERO` |
         * | Testo che scrivi tu | ⛔ no: parte come l'hai scritto |
         * | Foto di un pasto | ⛔ no, ma **ricodificata**: posizione e dati della fotocamera restano fuori |
         * | PDF di una scheda | ⛔ no: se la palestra ci ha stampato il nome, parte |
         *
         * 💡 Quindi la card dice **tutte e due le cose**. La prima è una
         * garanzia che diamo noi; la seconda dipende da cosa manda la persona,
         * ed è l'unica su cui può decidere lei — ma solo se gliela diciamo.
         */
        Card(
          margin: EdgeInsets.zero,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.no_accounts_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(
                        'Chi sei non parte mai',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: Gap.sm),

                Text(
                  'Alle richieste verso l\'intelligenza artificiale non '
                  'alleghiamo il tuo nome, la tua email, il tuo account né la '
                  'tua palestra. Dall\'altra parte arrivano numeri — calorie, '
                  'macro, minuti, battiti — senza niente che dica di chi sono.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: Gap.sm),

                Text(
                  'Le uniche cose che possono contenere qualcosa di tuo sono '
                  'quelle che mandi tu: il testo che scrivi per una stima, una '
                  'foto o il PDF di una scheda. Le foto le ricodifichiamo, '
                  'quindi la posizione dove le hai scattate resta fuori — ma '
                  'se scrivi il tuo nome in un testo, o se la palestra l\'ha '
                  'stampato sulla scheda, quello parte con il resto.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: Gap.sm),

                /*
                 * ⚠️ **I trenta giorni non si arrotondano a «non conservano
                 * niente»**: non abbiamo un accordo di conservazione zero, e
                 * `memory/informativa_privacy.md` §4 è scritta su questa
                 * verità. 🚨 Se un domani lo si ottiene, cambia questa frase
                 * **e** quella dell'informativa, insieme.
                 */
                Text(
                  'Anthropic non usa quello che le arriva per addestrare i '
                  'suoi modelli, e lo tiene al massimo trenta giorni.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
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
