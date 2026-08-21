import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/media/ritaglio_quadrato.dart';

/// Scegliere il quadrato dentro una foto già scattata — N11.1.
///
/// ── 💡 Perché serve solo per la galleria ───────────────────────────────────
///
/// Scattando dalla fotocamera nostra l'inquadratura l'ha già decisa la maschera
/// quadrata: quello che si vede è quello che si salva, e non c'è niente da
/// scegliere. Una foto **già scattata** invece ha le proporzioni che aveva —
/// l'ha composta qualcun altro, mesi fa — e ritagliarla al centro in silenzio
/// vorrebbe dire tagliare la testa a qualcuno senza avvisarlo.
///
/// 🚨 **Il riquadro che si vede È il riquadro che si salva.** L'immagine si
/// muove sotto una finestra quadrata ferma; alla conferma si calcola quale
/// pezzo dei **pixel originali** stava dentro quella finestra, e si ritaglia
/// esattamente quello.
class SchermataIngrandimento extends StatefulWidget {
  const SchermataIngrandimento({required this.byte, this.titolo, super.key});

  final Uint8List byte;
  final String? titolo;

  /// Apre la scelta e torna i byte **già ritagliati a 1080×1080**, o `null`.
  static Future<Uint8List?> apri(
    BuildContext context, {
    required Uint8List byte,
    String? titolo,
  }) => Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SchermataIngrandimento(byte: byte, titolo: titolo),
    ),
  );

  @override
  State<SchermataIngrandimento> createState() => _SchermataIngrandimentoState();
}

class _SchermataIngrandimentoState extends State<SchermataIngrandimento> {
  final _trasformazione = TransformationController();

  ui.Image? _immagine;
  bool _inCorso = false;

  /// Il lato della finestra quadrata, in pixel logici. Lo fissa il `build`.
  double _lato = 0;

  /// Quanto è grande l'immagine come viene disegnata, prima dei gesti.
  Size _disegnata = Size.zero;

  @override
  void initState() {
    super.initState();
    _misura();
  }

  @override
  void dispose() {
    _trasformazione.dispose();
    _immagine?.dispose();
    super.dispose();
  }

  Future<void> _misura() async {
    final decodificata = await decodeImageFromList(widget.byte);

    if (mounted) setState(() => _immagine = decodificata);
  }

  Future<void> _conferma() async {
    final immagine = _immagine;

    if (immagine == null || _inCorso) return;

    setState(() => _inCorso = true);

    /*
     * ── 🚨 Dal gesto ai pixel: la traduzione, e dove si sbaglia ─────────────
     *
     * `TransformationController` porta le coordinate **del figlio** a quelle
     * della finestra. A noi serve il contrario: quale pezzo del figlio sta
     * dentro la finestra. Quindi si **inverte** la matrice e le si danno i due
     * angoli della finestra.
     *
     * ⚠️ Il risultato è in pixel **disegnati**, non in pixel dell'immagine
     * originale: una foto da 4000 px mostrata larga 350 va riportata in scala,
     * o si ritaglierebbe un francobollo in alto a sinistra.
     */
    final ritagliata = await ritagliaQuadrato(
      byte: widget.byte,
      riquadro: riquadroInPixel(
        trasformazione: _trasformazione.value,
        lato: _lato,
        disegnata: _disegnata,
        larghezzaOriginale: immagine.width,
      ),
    );

    if (!mounted) return;

    if (ritagliata == null) {
      setState(() => _inCorso = false);

      return;
    }

    Navigator.of(context).pop(ritagliata);
  }

  @override
  Widget build(BuildContext context) {
    final immagine = _immagine;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.titolo ?? 'Scegli il quadrato'),
      ),
      body: SafeArea(
        child: immagine == null
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Column(
                children: [
                  Expanded(child: Center(child: _finestra(immagine))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Pizzica per ingrandire, trascina per spostare.',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _inCorso
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('Annulla'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            onPressed: _inCorso ? null : _conferma,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: _inCorso
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Va bene'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _finestra(ui.Image immagine) {
    return LayoutBuilder(
      builder: (context, spazio) {
        final lato = spazio.maxWidth < spazio.maxHeight
            ? spazio.maxWidth
            : spazio.maxHeight;

        /*
         * 💡 L'immagine parte **coprendo** il quadrato: il lato corto combacia
         * con la finestra e quello lungo esce dai bordi. ⚠️ Partire con
         * l'immagine intera dentro il quadrato lascerebbe due bande vuote che
         * finirebbero **dentro il ritaglio**, cioè due strisce nere nella foto
         * salvata.
         */
        final rapporto = immagine.width / immagine.height;
        final disegnata = rapporto > 1
            ? Size(lato * rapporto, lato)
            : Size(lato, lato / rapporto);

        if (_lato != lato || _disegnata != disegnata) {
          _lato = lato;
          _disegnata = disegnata;

          // ⚠️ Dopo il layout, non durante: toccare il controller qui dentro
          // farebbe ricostruire mentre si sta ancora costruendo.
          WidgetsBinding.instance.addPostFrameCallback((_) => _centra());
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: lato,
            height: lato,
            child: InteractiveViewer(
              transformationController: _trasformazione,
              // 🚨 `constrained: false`: il figlio tiene la sua misura vera e si
              // muove sotto la finestra. Con `true` Flutter lo rimpicciolirebbe
              // per farlo stare dentro, e non ci sarebbe niente da spostare.
              constrained: false,
              minScale: 1,
              maxScale: 6,
              child: SizedBox(
                width: disegnata.width,
                height: disegnata.height,
                child: Image.memory(widget.byte, fit: BoxFit.fill),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Mette il centro dell'immagine al centro della finestra.
  void _centra() {
    if (!mounted || _lato == 0) return;

    _trasformazione.value = Matrix4.identity()
      ..translateByDouble(
        -(_disegnata.width - _lato) / 2,
        -(_disegnata.height - _lato) / 2,
        0,
        1,
      );
  }
}

/// Quale pezzo dei **pixel originali** sta dentro la finestra quadrata — N11.2.
///
/// ── 🚨 La traduzione dal gesto ai pixel, e dove si sbaglia ──────────────
///
/// [trasformazione] porta le coordinate **del figlio** a quelle della finestra.
/// A noi serve il contrario — quale pezzo del figlio si vede — quindi si
/// **inverte** e le si danno i due angoli della finestra.
///
/// ⚠️ Il risultato di quel giro è in pixel **disegnati**, non originali: una
/// foto da 4000 px mostrata larga 350 va riportata in scala, o si ritaglierebbe
/// un francobollo in alto a sinistra. È il passaggio che si dimentica.
///
/// 💡 Sta fuori dal widget apposta: è la stessa promessa della fotocamera —
/// quello che vedi è quello che salvi — e dentro una schermata non si sarebbe
/// potuta provare. Vedi `test/media/riquadro_in_pixel_test.dart`.
@visibleForTesting
Rect riquadroInPixel({
  required Matrix4 trasformazione,
  required double lato,
  required Size disegnata,
  required int larghezzaOriginale,
}) {
  final inversa = Matrix4.inverted(trasformazione);

  final alto = MatrixUtils.transformPoint(inversa, Offset.zero);
  final basso = MatrixUtils.transformPoint(inversa, Offset(lato, lato));

  final scala = larghezzaOriginale / disegnata.width;

  return Rect.fromLTRB(
    alto.dx * scala,
    alto.dy * scala,
    basso.dx * scala,
    basso.dy * scala,
  );
}
