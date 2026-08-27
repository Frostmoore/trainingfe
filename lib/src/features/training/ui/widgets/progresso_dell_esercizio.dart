/// La progressione di un esercizio, sotto l'esercizio — 3b-I.A, 27/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// 📌 *«nella pagina della scheda possiamo mettere un grafico che indica i
/// progressi solo a chi è abbonato, con sotto un'analisi da parte dell'ai …
/// deve essere una per esercizio e deve essere renderata sotto quell'esercizio»*.
///
/// ══ 🚨 PERCHÉ SOTTO OGNI ESERCIZIO, E NON IN UNA SEZIONE SOLA ═════════════
///
/// ⛔ Avevo proposto l'alternativa — tutte le righe insieme in fondo — e sarebbe
/// stata **peggio**, non solo diversa: una riga che parla della panca, letta a
/// dieci centimetri dalla panca, si capisce senza dire di cosa parla. La stessa
/// riga in un elenco in fondo deve **ripetere il nome dell'esercizio** per
/// essere comprensibile, e diventa il muro di testo che volevo evitare.
///
/// ══ 🔒 SI VEDE CHE C'È, ANCHE SE NON SI PUÒ LEGGERE ═══════════════════════
///
/// 📌 *«i tasti per fare quella cosa ci devono essere e si deve capire che sono
/// bloccati dietro un abbonamento»*.
///
/// 💡 A chi non è abbonato la riga compare **sfocata**: si vede la forma, si
/// vede che c'è una frase, non si legge. ⛔ Un'assenza non convince nessuno —
/// chi non l'ha mai vista non sa che esiste.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../acquisti/ui/modale_acquisti.dart';
import '../../data/progressione.dart';
import '../../progressione_controller.dart';

class ProgressoDellEsercizio extends ConsumerWidget {
  const ProgressoDellEsercizio({
    required this.schedaLocale,
    required this.esercizioId,
    super.key,
  });

  final int schedaLocale;
  final int esercizioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puo = ref.watch(puoVedereIProgressiProvider);

    /*
     * ⚠️ **Anche a chi non è abbonato si legge lo storico vero.** 🚨 Non per
     * mostrarglielo — è sfocato — ma perché la riga deve comparire **solo se
     * quell'esercizio ha davvero una storia**: sfocare una sparkline finta
     * sotto un esercizio mai fatto sarebbe promettere una cosa che, dopo
     * l'abbonamento, non c'è. 💡 E i dati sono già sul telefono: non costa
     * niente e non esce niente.
     */
    final storia = ref
        .watch(storiaDellaSchedaProvider(schedaLocale))
        .valueOrNull;

    final punti = storia?[esercizioId] ?? const <PuntoDiProgressione>[];

    // ⛔ Meno di due sedute: non c'è nessuna progressione da disegnare, e una
    // linea di un punto sembrerebbe piatta — cioè direbbe «sei fermo».
    if (punti.length < 2) return const SizedBox.shrink();

    final riga = ref
        .watch(analisiDellaSchedaProvider(schedaLocale))
        .valueOrNull
        ?.per(esercizioId);

    final corpo = _Corpo(punti: punti, riga: riga, sfocato: !puo);

    /*
     * 💡 **Solo un margine sopra, e nessun margine laterale.** Questo widget
     * vive dentro la colonna dell'esercizio: allinearsi da solo vorrebbe dire
     * spostarsi rispetto al nome e alle serie a cui si riferisce.
     */
    return Padding(
      padding: const EdgeInsets.only(top: Gap.xs),
      child: puo
          ? corpo
          : InkWell(
              borderRadius: BorderRadius.circular(Gap.radiusSm),
              onTap: () => ModaleAcquisti.mostra(context),
              child: corpo,
            ),
    );
  }
}

class _Corpo extends StatelessWidget {
  const _Corpo({
    required this.punti,
    required this.riga,
    required this.sfocato,
  });

  final List<PuntoDiProgressione> punti;
  final ProgressoEsercizio? riga;
  final bool sfocato;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final andamento = riga?.andamento ?? andamentoDaiPunti(punti);
    final colore = _colore(tema.colorScheme, andamento);

    final dentro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 84,
              height: 24,
              child: CustomPaint(
                painter: _Sparkline(punti: punti, colore: colore),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Icon(_icona(andamento), size: 16, color: colore),
            const SizedBox(width: Gap.xs),
            Text(
              _etichetta(andamento),
              style: tema.textTheme.labelSmall?.copyWith(
                color: colore,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        /*
         * 💡 La frase compare **solo se c'è**. ⚠️ Può mancare per due ragioni
         * diverse — l'analisi non è mai stata chiesta, oppure il setaccio del
         * server ha svuotato la riga perché prescriveva qualcosa — e in
         * nessuno dei due casi c'è qualcosa di sensato da scrivere al suo
         * posto. ⛔ Un «nessuna analisi disponibile» sotto ogni esercizio
         * sarebbe il muro di testo, fatto di niente.
         */
        if (riga != null && riga!.riga.isNotEmpty) ...[
          const SizedBox(height: Gap.xs),
          Text(riga!.riga, style: tema.textTheme.bodySmall),
        ],
      ],
    );

    if (!sfocato) return dentro;

    /*
     * 🔒 **Sfocato, non nascosto.** ⚠️ `ImageFiltered` e non un `Opacity`: un
     * testo trasparente resta selezionabile e leggibile dagli strumenti di
     * accessibilità — cioè non è un limite, è un limite finto.
     *
     * 💡 `ExcludeSemantics` per la stessa ragione: quello che non si può
     * leggere non deve nemmeno essere letto ad alta voce.
     */
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 3.2, sigmaY: 3.2),
            child: dentro,
          ),
        ),
        Icon(
          Icons.lock_rounded,
          size: 18,
          color: tema.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}


IconData _icona(Andamento a) => switch (a) {
  Andamento.inSalita => Icons.trending_up_rounded,
  Andamento.fermo => Icons.trending_flat_rounded,
  Andamento.inCalo => Icons.trending_down_rounded,
  Andamento.pocoStorico => Icons.more_horiz_rounded,
};

String _etichetta(Andamento a) => switch (a) {
  Andamento.inSalita => 'in crescita',
  Andamento.fermo => 'stabile',
  Andamento.inCalo => 'in calo',
  Andamento.pocoStorico => 'poco storico',
};

/// ⚠️ **Il calo non è rosso.** Un `error` direbbe che hai sbagliato qualcosa:
/// scaricare è una cosa che si fa apposta, e dopo un'influenza è normale. 💡 Il
/// colore neutro descrive senza giudicare — che è esattamente il confine entro
/// cui questa funzione deve stare.
Color _colore(ColorScheme c, Andamento a) => switch (a) {
  Andamento.inSalita => c.primary,
  Andamento.fermo => c.onSurfaceVariant,
  Andamento.inCalo => c.tertiary,
  Andamento.pocoStorico => c.outline,
};

/// La linea dei carichi.
///
/// 💡 **Nessuna scala, nessun asse, nessun numero.** Non è un grafico da
/// leggere: è la forma di una tendenza. ⛔ Mettere i valori vorrebbe dire farli
/// stare in 84 pixel, cioè scriverli troppo piccoli per essere letti e troppo
/// grossi per essere ignorati.
class _Sparkline extends CustomPainter {
  const _Sparkline({required this.punti, required this.colore});

  final List<PuntoDiProgressione> punti;
  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    final valori = [
      for (final p in punti)
        if (p.valore != null) p.valore!,
    ];

    if (valori.length < 2) return;

    var minimo = valori.first;
    var massimo = valori.first;

    for (final v in valori) {
      if (v < minimo) minimo = v;
      if (v > massimo) massimo = v;
    }

    /*
     * ⚠️ **Una linea piatta va disegnata a metà, non in cima.** Con
     * `massimo == minimo` la divisione farebbe `0/0`: senza questo ramo la
     * sparkline di chi tiene lo stesso carico da un mese sparirebbe — cioè
     * proprio il caso in cui «sei fermo» è l'informazione.
     */
    final ampiezza = massimo - minimo;
    final passo = size.width / (valori.length - 1);

    final linea = Path();

    for (var i = 0; i < valori.length; i++) {
      final quota = ampiezza == 0 ? 0.5 : (valori[i] - minimo) / ampiezza;

      // 💡 `1 - quota`: in Flutter y cresce verso il basso, e un grafico che
      // scende quando il carico sale è il classico difetto che si vede solo
      // guardando.
      final y = size.height - (quota * size.height);
      final x = passo * i;

      i == 0 ? linea.moveTo(x, y) : linea.lineTo(x, y);
    }

    canvas.drawPath(
      linea,
      Paint()
        ..color = colore
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // L'ultimo punto, marcato: è quello che dice «sei qui».
    final ultima = ampiezza == 0 ? 0.5 : (valori.last - minimo) / ampiezza;

    canvas.drawCircle(
      Offset(size.width, size.height - (ultima * size.height)),
      2.6,
      Paint()..color = colore,
    );
  }

  @override
  bool shouldRepaint(_Sparkline vecchia) =>
      vecchia.colore != colore || vecchia.punti != punti;
}
