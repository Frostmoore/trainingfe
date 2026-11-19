import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../carica_batteria.dart';
import '../carica_controller.dart';
import '../forma_controller.dart';
import '../indice_di_effetto.dart';
import '../indice_di_effetto_controller.dart';
import '../indici_di_forma.dart';
import '../reattivita.dart';
import 'barra_carico.dart';

/// 🧩 **I pezzi della forma** — `plan_interfaccia.md` I2, 19/11/2026.
///
/// ══ 📌 COSA ERA, E PERCHÉ È STATO SMONTATO ════════════════════════════════
///
/// Fino al 19/11 qui c'era `SchedaForma`: la card «Carico e carica» di Oggi,
/// con l'avvertenza, il carico, l'Effetto, la prontezza e la carica uno sotto
/// l'altro (FASE 2-sexies, 3b-K, 3b-O.4, 08/09).
///
/// Con la nuova interfaccia **gli strumenti salgono nella testata scura**
/// (`PlanciaDiOggi`), e la card non ha più un posto. ⛔ Ma non si poteva
/// cancellare: dentro c'erano cose chieste una per una dal committente — la
/// frase sul perché della prontezza, l'affidabilità della carica, il «stamattina
/// eri a 86», l'Effetto del 07/09, la frase del 28/08 sulla carica che non è
/// una stima affidabile.
///
/// 💡 Quindi è stata **smontata nei suoi pezzi**, e ogni pezzo è pubblico:
///
/// | Pezzo | Dove va adesso |
/// |---|---|
/// | [AvvertenzaStima] | nel posto dell'avvertenza della testata, **sopra** i numeri; e in `SchermataForma` |
/// | [AvvertenzaDellaCarica] | subito sotto [AvvertenzaStima], quando la carica c'è |
/// | [SezioneCarico] | nella plancia, sotto il tachimetro |
/// | [fraseDellaProntezza] | nella plancia, sotto il tachimetro |
/// | [AffidabilitaDellaCarica] | nella plancia, in fondo |
/// | [SezioneEffetto] | nella tessera «Effetto» di «Andamento» |
/// | [fasciaDelCarico] | dentro [SezioneCarico] |

/// La fascia del carico, in parole.
///
/// 💡 **Le frasi sono le stesse di prima**: era la richiesta del 21/08.
String fasciaDelCarico(FasciaCarico? f) => switch (f) {
  FasciaCarico.scarico => 'sotto il tuo solito',
  FasciaCarico.normale => 'nella tua norma',
  FasciaCarico.inSalita => 'in salita',
  FasciaCarico.alto => 'molto sopra il solito',
  null => '',
};

/// L'avvertenza di tutti e tre gli indici.
///
/// 🚨 **Sta SOPRA i numeri** — decisione D-2s/B: sotto la leggerebbe chi ha già
/// letto i numeri, cioè troppo tardi.
class AvvertenzaStima extends StatelessWidget {
  const AvvertenzaStima({super.key});

  static const testo =
      'Stima calcolata dal telefono su sonno, battito, allenamenti e cibo. '
      'Non è una misura e non è un parere medico. '
      'È costruita sulle tue medie: non si confronta con quella di altri.';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colore = tema.colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 14, color: colore),
        const SizedBox(width: Gap.xs),
        Expanded(
          child: Text(
            testo,
            style: tema.textTheme.labelSmall?.copyWith(
              color: colore,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// ⚠️ **La carica non è una stima affidabile, e lo dice** — 28/08/2026.
///
/// 📌 *«carica mi piace, ma ci va una frase per capire che non è una stima
/// affidabile»*.
///
/// 🚨 **Questo numero è il più inventato dei tre.** Il carico è un rapporto fra
/// due medie di dati veri; la prontezza è uno scarto dalle proprie medie. La
/// Carica invece esce da una **catena di parametri scelti da noi** — 25, 10,
/// 0.55, 0.08 — che la specifica stessa chiama *«parametri di bootstrap
/// progettuali»*. ⛔ E si trascina: un errore di oggi resta nel numero di
/// domani.
///
/// 💡 Stava sotto la batteria, dentro la card; ora sta **con l'altra
/// avvertenza**, sopra i numeri, perché in testata accanto alla batteria non
/// c'è lo spazio per una frase di tre righe — e un'avvertenza tagliata non
/// avverte.
class AvvertenzaDellaCarica extends StatelessWidget {
  const AvvertenzaDellaCarica({super.key});

  static const testo =
      'La Carica è un modello, non una misura: i valori di partenza li '
      'abbiamo scelti noi e si affinano coi tuoi dati. Guardane l\'andamento '
      'nei giorni, non il numero preciso.';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      // Allineata al testo di [AvvertenzaStima], non alla sua icona.
      padding: const EdgeInsets.only(left: 14 + Gap.xs, top: Gap.xs),
      child: Text(
        testo,
        style: tema.textTheme.labelSmall?.copyWith(
          color: tema.colorScheme.onSurfaceVariant,
          height: 1.3,
        ),
      ),
    );
  }
}

/// Il carico: una barra, non un numero — 3b-O.4.3.
class SezioneCarico extends StatelessWidget {
  const SezioneCarico({required this.forma, super.key});

  final Forma forma;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final v = forma.stanchezza.valore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Carico', style: tema.textTheme.labelMedium),
            const SizedBox(width: Gap.sm),
            Text(
              /*
               * 💡 L'ACWR è un rapporto: «142%» vuol dire «il 142% del tuo
               * carico abituale», che è letteralmente quello che è.
               */
              v == null ? '—' : '${(v * 100).round()}%',
              style: tema.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: v == null
                    ? tema.colorScheme.outline
                    : tema.colorScheme.primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: Gap.xs),

        BarraCarico(acwr: v),

        const SizedBox(height: Gap.xs),

        Text(
          v == null
              ? 'Serve almeno un allenamento negli ultimi 28 giorni.'
              : fasciaDelCarico(forma.fascia),
          style: tema.textTheme.bodySmall,
        ),

        /*
         * 💡 La nota dice **quanti giorni mancano**, non «dati insufficienti»:
         * la prima è un'attesa che finisce, la seconda sembra un guasto.
         */
        if (v != null && !forma.stanchezza.eAttendibile)
          Text(
            'stima poco attendibile: mancano '
            '${forma.stanchezza.giorniCheMancano} giorni di dati',
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}

/// 🏃 Il Training Effect Index — 08/09/2026.
///
/// 📌 Il committente, il 07/09: *«ho scoperto una nuova misura che si chiama
/// PAI, va implementata nella stessa card del carico e scarico»*. Dal 19/11
/// la card non c'è più, e l'Effetto è una **tessera di «Andamento»**: è una
/// misura della settimana, come le altre di quella sezione.
///
/// 🚨 **Non è il PAI**: quella formula non è pubblica — brevetto NTNU, marchio
/// di PAI Health. Le due ancore da cui esce la nostra sono dichiarate in
/// `ModelloDiEffetto`.
///
/// ══ 🚨 QUANDO NON C'E', SI DICE COSA MANCA ════════════════════════════════
///
/// ⛔ **Tre cose lo rendono impossibile, e sono diverse fra loro**: l'età, il
/// battito a riposo e i battiti della settimana. Un «—» solo per tutti e tre
/// direbbe *«non funziona»* a chi deve solo scrivere la propria età.
class SezioneEffetto extends ConsumerWidget {
  const SezioneEffetto({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final tei = ref.watch(indiceDiEffettoProvider).valueOrNull;

    /*
     * ⛔ **`affidabile == false` non si mostra come un numero basso.** Un TEI a
     * 12 perché ti sei mosso poco e un TEI a 12 perché l'orologio era nel
     * cassetto sono la stessa cifra e due cose opposte.
     */
    final mostrabile = tei != null && tei.affidabile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              mostrabile ? '${tei.punti.round()}' : '—',
              style: tema.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: mostrabile
                    ? tema.colorScheme.primary
                    : tema.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 4),
            /*
             * 💡 **«su 100» sta scritto, e non è pignoleria**: senza, «112» non
             * si sa se è tanto o poco. ⚠️ Il 100 non è un tetto.
             */
            Text('/ 100', style: tema.textTheme.bodySmall),
          ],
        ),

        const SizedBox(height: Gap.xs),

        /*
         * ⚠️ Non la barra del carico: quella è un rapporto con il centro al
         * 100%, questa è un obiettivo da raggiungere. Una barra che si riempie
         * dice «arrivaci».
         */
        LinearProgressIndicator(
          value: mostrabile ? (tei.punti / 100).clamp(0.0, 1.0) : 0,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: tema.colorScheme.surfaceContainerHighest,
        ),

        const SizedBox(height: Gap.xs),

        Text(spiegazioneDellEffetto(tei), style: tema.textTheme.bodySmall),
      ],
    );
  }
}

/// Cosa c'è scritto sotto la barra dell'Effetto.
///
/// 🚨 **Ogni ramo è una causa diversa e un rimedio diverso**: chi deve scrivere
/// l'età in un campo e chi deve mettersi l'orologio non stanno facendo lo
/// stesso errore.
String spiegazioneDellEffetto(IndiceDiEffetto? tei) {
  if (tei == null) {
    return 'Serve la tua età nel profilo, un battito a riposo misurato e '
        'qualche giorno di orologio al polso.';
  }

  if (!tei.affidabile) {
    return 'L\'orologio ha registrato troppo poco per dirlo: il battito '
        'serve fitto, non una volta ogni tanto.';
  }

  if (tei.punti >= 100) {
    return 'Sei sopra l\'obiettivo settimanale. '
        '${tei.minutiUtili} minuti che hanno alzato il battito.';
  }

  return 'Ti mancano ${(100 - tei.punti).round()} punti per la settimana. '
      '${tei.minutiUtili} minuti utili finora.';
}

/// Perché la prontezza è così adesso, detto in una riga.
///
/// 🚨 **Ogni motivo è una causa diversa**, e serve a togliere l'aria di oracolo
/// al numero: *«sei sveglio da poco»* si capisce e si perdona, un 28 senza
/// spiegazione no.
///
/// ⚠️ **La frase cambia insieme al numero**: dal 07/09 la prontezza mostrata è
/// la **reattività** quando c'è, e «50 è il tuo normale» non descriverebbe più
/// quel numero. Una didascalia giusta sotto un numero diverso è il difetto
/// peggiore dei due.
String fraseDellaProntezza(Reattivita? r, double? valore) {
  if (r == null) {
    return valore == null
        ? 'non calcolabile'
        : 'Servono il sonno di stanotte e qualche dato dall\'orologio.';
  }

  return switch (r.motivo) {
    MotivoDellaReattivita.appenaSvegliato =>
      'Ti sei alzato da poco: l\'inerzia del risveglio passa in un\'ora.',
    MotivoDellaReattivita.dopoIlPasto =>
      'È la digestione: dopo un pasto pieno si scende, e risale da sé.',
    MotivoDellaReattivita.notteCorta =>
      'Hai dormito poco: oggi parti più in basso e cali prima.',
    MotivoDellaReattivita.troppeOreInPiedi =>
      'Sei sveglio da parecchie ore, e si sente.',
    MotivoDellaReattivita.cadutaCircadiana =>
      'È l\'ora in cui l\'orologio interno scende: capita a tutti.',
    MotivoDellaReattivita.caricoAllenamento =>
      'L\'allenamento di questi giorni si fa sentire.',

    // 💡 Nessun motivo che spicca **non è un errore**: stai dove il modello si
    // aspetta, ed è la maggior parte del tempo.
    null => 'Quanto sei reattivo adesso: cambia durante la giornata.',
  };
}

/// Quanto ci si può fidare della Carica, e **cosa manca** — 3b-K.
///
/// 📌 *«impedisce di presentare un 86% del secondo giorno come se avesse la
/// stessa precisione di un 86% calcolato dopo sei mesi di storico»*.
///
/// 🚨 **Dice anche cosa manca**, non solo che la stima è debole: «manca il
/// sonno» è una cosa a cui si può rimediare, «poco affidabile» no.
class AffidabilitaDellaCarica extends StatelessWidget {
  const AffidabilitaDellaCarica({required this.carica, super.key});

  final Carica carica;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colore = tema.colorScheme.onSurfaceVariant;

    final mancano = [
      if (carica.senzaAttivita) 'le calorie di oggi',
      if (carica.senzaSonno) 'il sonno di stanotte',
      if (carica.senzaFisiologia) 'battito e variabilità',
    ];

    final parola = switch (carica.affidabilita) {
      Affidabilita.bassa => 'bassa',
      Affidabilita.media => 'media',
      Affidabilita.alta => 'alta',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Carica: affidabilità $parola · ${carica.giorniValidi} giorni di dati',
          style: tema.textTheme.labelSmall?.copyWith(color: colore),
        ),

        /*
         * 💡 **«Stamattina eri a 86»**: la Carica cala durante la giornata, e
         * senza il punto di partenza un 71 non si distingue da un 71 con cui ci
         * si è svegliati. ⚠️ Solo se è calata davvero.
         */
        if (carica.mattina - carica.adesso >= 1)
          Text(
            'stamattina eri a ${carica.mattina.round()}',
            style: tema.textTheme.labelSmall?.copyWith(color: colore),
          ),

        if (mancano.isNotEmpty)
          Text(
            'manca ${mancano.join(", ")}',
            style: tema.textTheme.labelSmall?.copyWith(
              color: colore,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}
