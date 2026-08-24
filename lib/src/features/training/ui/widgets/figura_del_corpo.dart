/// La figura del corpo colorata per zone — 3b-A.6.1 / 3b-B.1, 24/08/2026.
///
/// ══ 📌 LA RICHIESTA, E COME È CAMBIATA ════════════════════════════════════
///
/// *«una con un uomo vitruviano visto davanti e indietro [...] in cui i muscoli
/// e i gruppi muscolari più allenati hanno un colore rosso più intenso. Questa
/// creala come **servizio riutilizzabile**»*.
///
/// ⛔ **Al primo giro era disegnata a mano**, con dei rettangoli arrotondati, e
/// il committente l'ha bocciata: *«L'uomo è orribile, credo che sia meglio se ti
/// passo il png di un uomo e tu ci colori sopra»*. Aveva ragione: un corpo fatto
/// di rettangoli sembra un manichino smontato, e nessun raccordo lo salvava.
///
/// 💡 Adesso la sagoma è un'**immagine anatomica** che ci ha dato lui, e il
/// colore ci va **dentro**.
///
/// ── 🚨 Come il colore resta dentro il corpo ───────────────────────────────
///
/// ⛔ Disegnare le macchie sopra l'immagine le farebbe debordare sul fondo: una
/// zona è un rettangolo, un braccio è obliquo. ⚠️ E ritagliarle a mano vorrebbe
/// dire ridisegnare la sagoma — cioè tornare al punto di partenza.
///
/// 💡 Si usa l'immagine **come maschera**: dentro un `saveLayer` si dipingono le
/// macchie, poi si applica la sagoma con `BlendMode.dstIn`. Quello che resta è
/// il colore **solo dove c'è corpo** — e siccome i solchi fra i muscoli sono
/// trasparenti nel PNG, il rosso segue le fibre invece di essere una macchia
/// piatta.
///
/// ── ⚠️ Uomo o donna ───────────────────────────────────────────────────────
///
/// 📌 *«Ovviamente un uomo deve vedere quella da uomo e una donna quella da
/// donna»*. Il sesso viene dal profilo (`UserProfile.sex`), e **chi non l'ha
/// dichiarato vede la figura maschile**: una delle due va scelta comunque, e
/// non c'è una terza immagine da mostrare.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/profile_controller.dart';
import '../../data/gruppo_muscolare.dart';

/// Quale corpo si disegna.
enum CorpoDa {
  uomo('uomo'),
  donna('donna');

  const CorpoDa(this.cartella);

  final String cartella;

  /// 💡 `null`, una stringa vuota o un valore che non conosciamo → uomo.
  static CorpoDa dalSesso(String? sesso) =>
      sesso?.toLowerCase() == 'female' ? CorpoDa.donna : CorpoDa.uomo;
}

/// Le sagome, caricate una volta per vita dell'app.
///
/// 🚨 **Non `autoDispose`**: sono quattro PNG da ottanta kilobyte, e la figura
/// compare nel carosello **e** in ogni pagina di allenamento. Ricaricarli a ogni
/// cambio di schermata vorrebbe dire decodificarli decine di volte.
final sagomaDelCorpoProvider = FutureProvider.family<ui.Image, String>((
  ref,
  nome,
) async {
  final dati = await rootBundle.load('assets/corpo/$nome.png');

  final codificatore = await ui.instantiateImageCodec(
    dati.buffer.asUint8List(),
  );

  return (await codificatore.getNextFrame()).image;
});

/// Il servizio riutilizzabile: dalle intensità al disegno.
class FiguraDelCorpo extends ConsumerWidget {
  const FiguraDelCorpo({
    required this.intensita,
    this.mostraDietro = true,
    this.corpo,
    super.key,
  });

  /// `gruppo → 0..1`. Quello che manca resta **spento**, non zero rosso.
  final Map<GruppoMuscolare, double> intensita;

  /// Se disegnare anche la schiena accanto al davanti.
  final bool mostraDietro;

  /// Forzare uomo o donna. `null` = lo decide il profilo.
  final CorpoDa? corpo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    /*
     * ⚠️ `valueOrNull`: se il profilo non è ancora arrivato — o non arriva
     * affatto, perché la rete non va — si disegna comunque. ⛔ Aspettarlo
     * vorrebbe dire una card vuota per una figura che il profilo lo usa solo
     * per scegliere fra due immagini.
     */
    final quale =
        corpo ?? CorpoDa.dalSesso(ref.watch(profileProvider).valueOrNull?.sex);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final davanti in [true, if (mostraDietro) false])
          Expanded(
            child: _UnaFigura(
              nome: '${quale.cartella}_${davanti ? 'davanti' : 'dietro'}',
              intensita: intensita,
              davanti: davanti,
              spento: tema.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
              acceso: tema.colorScheme.error,
            ),
          ),
      ],
    );
  }
}

class _UnaFigura extends ConsumerWidget {
  const _UnaFigura({
    required this.nome,
    required this.intensita,
    required this.davanti,
    required this.spento,
    required this.acceso,
  });

  final String nome;
  final Map<GruppoMuscolare, double> intensita;
  final bool davanti;
  final Color spento;
  final Color acceso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sagoma = ref.watch(sagomaDelCorpoProvider(nome)).valueOrNull;

    /*
     * ⚠️ Mentre carica non si disegna **niente**, nemmeno un giro di
     * caricamento: sono asset locali, ci mettono un fotogramma, e una rotellina
     * che lampeggia a ogni apertura darebbe l'idea di una cosa lenta.
     */
    if (sagoma == null) return const SizedBox.shrink();

    return CustomPaint(
      painter: _PittoreDelCorpo(
        sagoma: sagoma,
        intensita: intensita,
        davanti: davanti,
        spento: spento,
        acceso: acceso,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Da che parte si vede una zona.
enum _Lato { davanti, dietro, entrambi }

class _Zona {
  const _Zona(this.lato, this.forme);

  final _Lato lato;

  /// Le forme in coordinate **0..1 sulla figura**, non sul riquadro.
  final List<Rect> forme;
}

/// Dove sta ogni gruppo sul corpo.
///
/// 🚨 **Le coordinate sono rifatte sull'immagine vera**: quelle del disegno a
/// rettangoli non c'entravano più niente. ⚠️ Sono generose di proposito — tanto
/// la maschera taglia via quello che esce dal corpo, quindi è meglio abbondare
/// che lasciare un bordo di muscolo spento.
///
/// ⛔ `cardio` e `full_body` non compaiono: non sono zone del corpo.
const _zone = <GruppoMuscolare, _Zona>{
  GruppoMuscolare.spalle: _Zona(_Lato.entrambi, [
    Rect.fromLTRB(0.18, 0.130, 0.40, 0.235),
    Rect.fromLTRB(0.60, 0.130, 0.82, 0.235),
  ]),
  GruppoMuscolare.petto: _Zona(_Lato.davanti, [
    Rect.fromLTRB(0.34, 0.150, 0.66, 0.265),
  ]),
  GruppoMuscolare.schiena: _Zona(_Lato.dietro, [
    Rect.fromLTRB(0.31, 0.140, 0.69, 0.390),
  ]),
  GruppoMuscolare.addome: _Zona(_Lato.davanti, [
    Rect.fromLTRB(0.38, 0.265, 0.62, 0.430),
  ]),
  GruppoMuscolare.bicipiti: _Zona(_Lato.davanti, [
    Rect.fromLTRB(0.15, 0.200, 0.34, 0.320),
    Rect.fromLTRB(0.66, 0.200, 0.85, 0.320),
  ]),
  GruppoMuscolare.tricipiti: _Zona(_Lato.dietro, [
    Rect.fromLTRB(0.15, 0.200, 0.34, 0.320),
    Rect.fromLTRB(0.66, 0.200, 0.85, 0.320),
  ]),
  GruppoMuscolare.avambracci: _Zona(_Lato.entrambi, [
    Rect.fromLTRB(0.02, 0.300, 0.24, 0.440),
    Rect.fromLTRB(0.76, 0.300, 0.98, 0.440),
  ]),
  GruppoMuscolare.glutei: _Zona(_Lato.dietro, [
    Rect.fromLTRB(0.33, 0.385, 0.67, 0.505),
  ]),
  GruppoMuscolare.quadricipiti: _Zona(_Lato.davanti, [
    Rect.fromLTRB(0.32, 0.440, 0.50, 0.680),
    Rect.fromLTRB(0.50, 0.440, 0.68, 0.680),
  ]),
  GruppoMuscolare.femorali: _Zona(_Lato.dietro, [
    Rect.fromLTRB(0.32, 0.480, 0.50, 0.690),
    Rect.fromLTRB(0.50, 0.480, 0.68, 0.690),
  ]),
  GruppoMuscolare.polpacci: _Zona(_Lato.entrambi, [
    Rect.fromLTRB(0.33, 0.700, 0.50, 0.885),
    Rect.fromLTRB(0.50, 0.700, 0.67, 0.885),
  ]),
};

class _PittoreDelCorpo extends CustomPainter {
  const _PittoreDelCorpo({
    required this.sagoma,
    required this.intensita,
    required this.davanti,
    required this.spento,
    required this.acceso,
  });

  final ui.Image sagoma;
  final Map<GruppoMuscolare, double> intensita;
  final bool davanti;
  final Color spento;
  final Color acceso;

  @override
  void paint(Canvas canvas, Size size) {
    /*
     * ⚠️ **Il rapporto lo decide l'immagine.** Deformare un corpo per riempire
     * un riquadro qualunque è la cosa che si nota per prima, e non si smette
     * più di vederla.
     */
    final scala = (size.width / sagoma.width) < (size.height / sagoma.height)
        ? size.width / sagoma.width
        : size.height / sagoma.height;

    final larghezza = sagoma.width * scala;
    final altezza = sagoma.height * scala;

    final dove = Rect.fromLTWH(
      (size.width - larghezza) / 2,
      (size.height - altezza) / 2,
      larghezza,
      altezza,
    );

    final sorgente = Rect.fromLTWH(
      0,
      0,
      sagoma.width.toDouble(),
      sagoma.height.toDouble(),
    );

    // ── 1. La sagoma spenta ──────────────────────────────────────────────
    canvas.drawImageRect(
      sagoma,
      sorgente,
      dove,
      Paint()..colorFilter = ColorFilter.mode(spento, BlendMode.srcIn),
    );

    // ── 2. Le zone accese, ritagliate dentro il corpo ────────────────────
    final accese = _zone.entries.where((e) {
      final visibile =
          e.value.lato == _Lato.entrambi ||
          (davanti
              ? e.value.lato == _Lato.davanti
              : e.value.lato == _Lato.dietro);

      /*
       * ⛔ **Zero non si disegna.** Un rosso appena accennato su un muscolo mai
       * allenato direbbe che qualcosa hai fatto, e la figura serve proprio a
       * distinguere il niente dal poco.
       */
      return visibile && (intensita[e.key] ?? 0) > 0;
    }).toList();

    if (accese.isEmpty) return;

    /*
     * 🚨 **`saveLayer` e poi `dstIn`**: si dipinge su un foglio a parte, e alla
     * fine la sagoma fa da stampo. ⚠️ Senza il layer, `dstIn` cancellerebbe
     * tutto quello che c'è sotto nel canvas — compresa la figura spenta.
     */
    canvas.saveLayer(dove, Paint());

    for (final e in accese) {
      final quanto = intensita[e.key]!;

      /*
       * 💡 L'opacità parte da 0,3: un'intensità dello 0,02 con opacità 0,02
       * sarebbe invisibile, e il muscolo sembrerebbe non allenato. ⚠️ Sotto una
       * certa soglia il colore deve **esserci**, anche pallido.
       */
      final tinta = acceso.withValues(alpha: 0.30 + 0.70 * quanto);

      for (final forma in e.value.forme) {
        canvas.drawRect(
          Rect.fromLTRB(
            dove.left + forma.left * dove.width,
            dove.top + forma.top * dove.height,
            dove.left + forma.right * dove.width,
            dove.top + forma.bottom * dove.height,
          ),
          Paint()..color = tinta,
        );
      }
    }

    canvas.drawImageRect(
      sagoma,
      sorgente,
      dove,
      Paint()..blendMode = BlendMode.dstIn,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PittoreDelCorpo vecchio) =>
      vecchio.davanti != davanti ||
      vecchio.acceso != acceso ||
      vecchio.sagoma != sagoma ||
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

/// Una sagoma bianca finta, per i test.
///
/// ⚠️ Serve perché un test di widget **non può leggere gli asset veri** senza
/// impacchettarli: `rootBundle` in un test non ha i PNG. 💡 Un quadrato opaco fa
/// la stessa cosa per quello che il pittore deve dimostrare — che disegna, che
/// non sfora e che a zero tace.
@visibleForTesting
Future<ui.Image> sagomaFinta({int lato = 64}) async {
  final dati = Uint8List(lato * lato * 4)..fillRange(0, lato * lato * 4, 255);

  final buffer = await ui.ImmutableBuffer.fromUint8List(dati);

  final descrittore = ui.ImageDescriptor.raw(
    buffer,
    width: lato,
    height: lato,
    pixelFormat: ui.PixelFormat.rgba8888,
  );

  return (await (await descrittore.instantiateCodec()).getNextFrame()).image;
}
