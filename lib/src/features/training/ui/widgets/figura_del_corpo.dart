/// La figura del corpo colorata per zone — 3b-A.6.1, 24/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«una con un uomo vitruviano visto davanti e indietro (non proprio un uomo
/// vitruviano, ovviamente, ma un'immagine di un uomo) in cui i muscoli e i
/// gruppi muscolari più allenati hanno un colore rosso più intenso. Questa
/// creala come **servizio riutilizzabile**, perché dovrà andare anche in ogni
/// pagina dell'allenamento specifico»*.
///
/// ── 🚨 Disegnata, non un'immagine ─────────────────────────────────────────
///
/// ⛔ **Niente SVG e niente PNG**, ed è una scelta con tre ragioni:
///
/// 1. un'immagine di un corpo va **licenziata**, e una figura anatomica
///    trovata in giro è il tipo di cosa che si scopre di non poter usare il
///    giorno della pubblicazione;
/// 2. per colorare zona per zona servirebbe comunque un SVG con un `id` per
///    muscolo, cioè un file che qualcuno deve disegnare **e mantenere allineato
///    all'enum**: il giorno che si aggiunge un gruppo, l'immagine tace;
/// 3. `flutter_svg` sarebbe una dipendenza in più per disegnare quindici forme.
///
/// 💡 Qui ogni zona è un `Path` **nostro**, in coordinate 0..1, e la mappa
/// `gruppo → zona` è nel codice: se un gruppo non ha una zona, l'analizzatore
/// non se ne accorge — ma il test sì (`figura_del_corpo_test.dart`).
///
/// ⚠️ **È stilizzata, non anatomica**, e va bene così: deve rispondere a «quali
/// zone ho allenato», non insegnare miologia.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/gruppo_muscolare.dart';

/// Il servizio riutilizzabile: dalle intensità al disegno.
///
/// 🚨 **Un widget e non una funzione che torna un'immagine**: va in una card
/// del carosello, nella pagina di un allenamento e — un domani — dove serve. Un
/// widget si mette dove si vuole; un'immagine generata andrebbe misurata,
/// messa in cache e invalidata a mano.
class FiguraDelCorpo extends StatelessWidget {
  const FiguraDelCorpo({
    required this.intensita,
    this.mostraDietro = true,
    super.key,
  });

  /// `gruppo → 0..1`. Quello che manca è **grigio**, non zero rosso.
  final Map<GruppoMuscolare, double> intensita;

  /// Se disegnare anche la schiena accanto al davanti.
  ///
  /// 💡 In una card stretta si può volere solo il davanti: metà delle zone
  /// stanno lì, e due figure in 150 px non si leggono.
  final bool mostraDietro;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return LayoutBuilder(
      builder: (context, vincoli) {
        /*
         * ⚠️ **Il rapporto lo decide la figura, non il contenitore.** Un corpo
         * disegnato in un riquadro qualunque si deforma: qui si calcola il
         * quadrato più grande che ci sta e si disegna dentro quello.
         */
        final quante = mostraDietro ? 2 : 1;
        final larghezzaPerFigura = vincoli.maxWidth / quante;
        final lato = larghezzaPerFigura < vincoli.maxHeight / _rapporto
            ? larghezzaPerFigura
            : vincoli.maxHeight / _rapporto;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final davanti in [true, if (mostraDietro) false])
              SizedBox(
                width: lato,
                height: lato * _rapporto,
                child: CustomPaint(
                  painter: _PittoreDelCorpo(
                    intensita: intensita,
                    davanti: davanti,
                    spento: tema.colorScheme.surfaceContainerHighest,
                    contorno: tema.colorScheme.outlineVariant,
                    acceso: tema.colorScheme.error,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Quanto è alta la figura rispetto alla sua larghezza.
  static const _rapporto = 2.3;
}

/// Da che parte si vede una zona.
enum _Lato { davanti, dietro, entrambi }

class _Zona {
  const _Zona(this.lato, this.forme);

  final _Lato lato;

  /// Le forme in coordinate **0..1**, così la figura scala con il riquadro.
  final List<Rect> forme;
}

/// Dove sta ogni gruppo sul corpo.
///
/// 🚨 **Rettangoli arrotondati e non sagome**: una sagoma anatomica sarebbe
/// centinaia di punti da mantenere, e a 150 px di altezza non si distinguerebbe
/// da questa. ⚠️ Quello che deve funzionare è **riconoscere la zona**, e per
/// quello la posizione conta più della forma.
///
/// ⛔ `cardio` e `full_body` non compaiono, e non è una dimenticanza: non sono
/// zone del corpo (`GruppoMuscolare.eUnMuscolo`).
const _zone = <GruppoMuscolare, _Zona>{
  GruppoMuscolare.spalle: _Zona(_Lato.entrambi, [
    Rect.fromLTRB(0.195, 0.168, 0.320, 0.240),
    Rect.fromLTRB(0.680, 0.168, 0.805, 0.240),
  ]),
  GruppoMuscolare.petto: _Zona(_Lato.davanti, [
    Rect.fromLTRB(0.320, 0.200, 0.680, 0.290),
  ]),
  GruppoMuscolare.schiena: _Zona(_Lato.dietro, [
    Rect.fromLTRB(0.310, 0.195, 0.690, 0.360),
  ]),
  GruppoMuscolare.addome: _Zona(_Lato.davanti, [
    Rect.fromLTRB(0.355, 0.300, 0.645, 0.420),
  ]),
  GruppoMuscolare.bicipiti: _Zona(_Lato.davanti, [
    Rect.fromLTRB(0.155, 0.250, 0.280, 0.340),
    Rect.fromLTRB(0.720, 0.250, 0.845, 0.340),
  ]),
  GruppoMuscolare.tricipiti: _Zona(_Lato.dietro, [
    Rect.fromLTRB(0.155, 0.250, 0.280, 0.340),
    Rect.fromLTRB(0.720, 0.250, 0.845, 0.340),
  ]),
  GruppoMuscolare.avambracci: _Zona(_Lato.entrambi, [
    Rect.fromLTRB(0.155, 0.352, 0.280, 0.440),
    Rect.fromLTRB(0.720, 0.352, 0.845, 0.440),
  ]),
  GruppoMuscolare.glutei: _Zona(_Lato.dietro, [
    Rect.fromLTRB(0.330, 0.400, 0.670, 0.495),
  ]),
  GruppoMuscolare.quadricipiti: _Zona(_Lato.davanti, [
    Rect.fromLTRB(0.330, 0.470, 0.470, 0.650),
    Rect.fromLTRB(0.530, 0.470, 0.670, 0.650),
  ]),
  GruppoMuscolare.femorali: _Zona(_Lato.dietro, [
    Rect.fromLTRB(0.330, 0.505, 0.470, 0.665),
    Rect.fromLTRB(0.530, 0.505, 0.670, 0.665),
  ]),
  GruppoMuscolare.polpacci: _Zona(_Lato.entrambi, [
    Rect.fromLTRB(0.335, 0.700, 0.465, 0.865),
    Rect.fromLTRB(0.535, 0.700, 0.665, 0.865),
  ]),
};

class _PittoreDelCorpo extends CustomPainter {
  const _PittoreDelCorpo({
    required this.intensita,
    required this.davanti,
    required this.spento,
    required this.contorno,
    required this.acceso,
  });

  final Map<GruppoMuscolare, double> intensita;
  final bool davanti;
  final Color spento;
  final Color contorno;
  final Color acceso;

  @override
  void paint(Canvas canvas, Size size) {
    final sagoma = Paint()
      ..color = spento
      ..style = PaintingStyle.fill;

    /*
     * ══ 🚨 LE PARTI SI SOVRAPPONGONO, O È UN LEGO ═════════════════════════
     *
     * ⛔ Al primo giro testa, braccia, tronco e gambe erano quattro rettangoli
     * **staccati**, con dei buchi in mezzo. Visto a schermo il 24/08: sembrava
     * un manichino smontato, non un corpo.
     *
     * 💡 Adesso ogni pezzo entra dentro il vicino di qualche punto — il collo
     * nel tronco, le braccia nelle spalle, le gambe nel bacino — e i raggi sono
     * grandi. ⚠️ Resta **stilizzata**, e va bene: deve rispondere a «quali zone
     * ho allenato», non insegnare anatomia.
     */
    // Il collo, che è quello che teneva staccata la testa.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        _r(const Rect.fromLTRB(0.455, 0.100, 0.545, 0.185), size),
        const Radius.circular(6),
      ),
      sagoma,
    );

    canvas.drawOval(
      _r(const Rect.fromLTRB(0.415, 0.015, 0.585, 0.125), size),
      sagoma,
    );

    for (final (r, raggio) in const [
      // Le spalle: più larghe del tronco, e sono loro a raccordare le braccia.
      (Rect.fromLTRB(0.185, 0.155, 0.815, 0.245), 26.0),
      (Rect.fromLTRB(0.285, 0.165, 0.715, 0.430), 20.0), // torace
      (Rect.fromLTRB(0.315, 0.380, 0.685, 0.510), 18.0), // bacino
      (Rect.fromLTRB(0.145, 0.180, 0.290, 0.450), 20.0), // braccio sinistro
      (Rect.fromLTRB(0.710, 0.180, 0.855, 0.450), 20.0), // braccio destro
      (Rect.fromLTRB(0.320, 0.450, 0.480, 0.890), 22.0), // gamba sinistra
      (Rect.fromLTRB(0.520, 0.450, 0.680, 0.890), 22.0), // gamba destra
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(r, size), Radius.circular(raggio)),
        sagoma,
      );
    }

    // ── Le zone accese ───────────────────────────────────────────────────
    _zone.forEach((gruppo, zona) {
      final siVede =
          zona.lato == _Lato.entrambi ||
          (davanti ? zona.lato == _Lato.davanti : zona.lato == _Lato.dietro);

      if (!siVede) return;

      final quanto = intensita[gruppo] ?? 0;

      /*
       * ⛔ **Zero non si disegna.** Un rosso appena accennato su un muscolo mai
       * allenato direbbe che qualcosa hai fatto, e la figura serve proprio a
       * distinguere il niente dal poco.
       */
      if (quanto <= 0) return;

      /*
       * 💡 L'opacità parte da 0,25 e non da 0: un'intensità dello 0,02 con
       * opacità 0,02 sarebbe invisibile, e il muscolo sembrerebbe non allenato.
       * ⚠️ Sotto una certa soglia il colore deve **esserci**, anche pallido.
       */
      final tinta = acceso.withValues(alpha: 0.25 + 0.75 * quanto);

      for (final forma in zona.forme) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(_r(forma, size), const Radius.circular(8)),
          Paint()..color = tinta,
        );
      }
    });

    // ── Il contorno, che tiene insieme la figura ─────────────────────────
    final bordo = Paint()
      ..color = contorno
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    /*
     * ⚠️ **Il contorno si disegna solo sul perimetro esterno**, cioè testa,
     * braccia e gambe. ⛔ Ripassarlo su tronco e bacino disegnerebbe le linee
     * **dentro** la figura, e le sovrapposizioni che tengono insieme il corpo
     * tornerebbero a vedersi come cuciture.
     */
    canvas.drawOval(
      _r(const Rect.fromLTRB(0.415, 0.015, 0.585, 0.125), size),
      bordo,
    );

    for (final (r, raggio) in const [
      (Rect.fromLTRB(0.145, 0.180, 0.290, 0.450), 20.0),
      (Rect.fromLTRB(0.710, 0.180, 0.855, 0.450), 20.0),
      (Rect.fromLTRB(0.320, 0.450, 0.480, 0.890), 22.0),
      (Rect.fromLTRB(0.520, 0.450, 0.680, 0.890), 22.0),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(r, size), Radius.circular(raggio)),
        bordo,
      );
    }

    // ── «davanti» / «dietro», o non si sa cosa si sta guardando ──────────
    final testo =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              fontSize: size.width * 0.09,
              fontWeight: FontWeight.w600,
            ),
          )
          ..pushStyle(ui.TextStyle(color: contorno))
          ..addText(davanti ? 'davanti' : 'dietro');

    final p = testo.build()..layout(ui.ParagraphConstraints(width: size.width));

    canvas.drawParagraph(p, Offset(0, size.height - p.height));
  }

  /// Da coordinate 0..1 a pixel.
  static Rect _r(Rect q, Size s) => Rect.fromLTRB(
    q.left * s.width,
    q.top * s.height,
    q.right * s.width,
    q.bottom * s.height,
  );

  @override
  bool shouldRepaint(_PittoreDelCorpo vecchio) =>
      vecchio.davanti != davanti ||
      vecchio.acceso != acceso ||
      !_stesseIntensita(vecchio.intensita, intensita);

  static bool _stesseIntensita(
    Map<GruppoMuscolare, double> a,
    Map<GruppoMuscolare, double> b,
  ) {
    if (a.length != b.length) return false;

    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }

    return true;
  }
}

/// I gruppi che la figura sa disegnare.
///
/// 🚨 **Pubblica apposta**: è quello su cui il test verifica che ogni muscolo
/// dell'enum abbia una zona. ⛔ Senza, aggiungere un gruppo domani lascerebbe
/// una parte del corpo che non si accende mai — e nessuno se ne accorgerebbe,
/// perché non è un errore: è un silenzio.
Set<GruppoMuscolare> get gruppiDisegnati => _zone.keys.toSet();
