
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/media/ritaglio_quadrato.dart';

/// La fotocamera nostra, con l'inquadratura quadrata — N10.
///
/// ── 🚨 Perché non basta quella di sistema ──────────────────────────────────
///
/// Su quella di sistema non si può disegnare niente. Chi inquadra una cosa si
/// ritroverebbe salvata un'altra — la testa tagliata in una foto di progresso è
/// il caso tipico, e lo si scopre solo dopo.
///
/// ── 🚨 La promessa: quello che vedi è quello che salvi ─────────────────────
///
/// È tutta la ragione per cui questa schermata esiste, ed è anche la cosa
/// facile da sbagliare. L'anteprima sta dentro un **riquadro quadrato che
/// ritaglia il centro** del fotogramma (`BoxFit.cover` dentro un
/// `AspectRatio(1)`), e lo scatto viene ritagliato **al centro** dalla stessa
/// funzione. Le due operazioni devono restare l'una lo specchio dell'altra:
/// cambiando l'una senza l'altra, la promessa salta in silenzio.
///
/// ⚠️ Si torna con il percorso di un file **temporaneo già ritagliato a
/// 1080×1080**, oppure `null` se si è usciti. Chi chiama decide dove metterlo:
/// questa schermata non sa niente di [TipoFoto].
class SchermataFotocamera extends StatefulWidget {
  const SchermataFotocamera({this.titolo, super.key});

  /// Cosa si sta fotografando, scritto in cima. Es. «La foto di oggi».
  final String? titolo;

  /// Apre la fotocamera e torna i byte della foto ritagliata, o `null`.
  static Future<Uint8List?> apri(BuildContext context, {String? titolo}) =>
      Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => SchermataFotocamera(titolo: titolo),
        ),
      );

  @override
  State<SchermataFotocamera> createState() => _SchermataFotocameraState();
}

class _SchermataFotocameraState extends State<SchermataFotocamera> {
  CameraController? _controllore;
  List<CameraDescription> _fotocamere = const [];
  int _quale = 0;

  FlashMode _flash = FlashMode.off;
  bool _scattando = false;
  String? _guasto;

  @override
  void initState() {
    super.initState();

    /*
     * ── 🚨 Solo verticale, e si rimette com'era all'uscita ─────────────────
     *
     * Una foto di progresso ruotata è una foto che non si può confrontare con
     * le altre: bloccando l'orientamento il problema non si pone, invece di
     * doverlo correggere dopo.
     *
     * ⚠️ Il ripristino in `dispose` è **la riga che si dimentica**. Senza,
     * l'app **intera** resta bloccata in verticale, e il difetto si manifesta
     * lontano dalla causa — in una schermata che con la fotocamera non
     * c'entra niente, dove nessuno andrà a cercarlo.
     */
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _avvia();
  }

  @override
  void dispose() {
    // ⚠️ Lista vuota = «tutti gli orientamenti», cioè com'era prima.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _controllore?.dispose();

    super.dispose();
  }

  Future<void> _avvia() async {
    try {
      _fotocamere = await availableCameras();

      if (_fotocamere.isEmpty) {
        setState(() => _guasto = 'Su questo telefono non trovo la fotocamera.');

        return;
      }

      await _accendi(_quale);
    } on Object catch (e) {
      /*
       * ── 🚨 Si prende TUTTO, non solo `CameraException` ─────────────────
       *
       * ⚠️ `availableCameras()` non lancia solo eccezioni della fotocamera:
       * dove il plugin non è registrato — un test, un emulatore mal
       * configurato, una piattaforma non supportata — arriva una
       * `MissingPluginException`, che è tutt'altro tipo. Prendendo solo
       * `CameraException` quella sfuggirebbe e **farebbe crollare la
       * schermata** invece di mostrare un messaggio.
       *
       * 💡 Il caso più frequente però non è un guasto: è **il permesso
       * negato**, e merita di dire cosa fare. Un «CameraAccessDenied» lasciato
       * passare così com'è manderebbe qualcuno a cercare un difetto che non c'è.
       */
      if (!mounted) return;

      final negato = e is CameraException && e.code.contains('Denied');

      setState(() {
        _guasto = negato
            ? 'Per scattare serve il permesso della fotocamera. '
                  'Puoi darglielo dalle impostazioni del telefono.'
            : 'Non riesco ad aprire la fotocamera su questo telefono.';
      });
    }
  }

  Future<void> _accendi(int indice) async {
    await _controllore?.dispose();

    final c = CameraController(
      _fotocamere[indice],
      // 💡 `high` e non `max`: ci serve un quadrato da 1080, e un sensore da 108
      // megapixel darebbe solo un fotogramma lentissimo da ritagliare.
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await c.initialize();

    /*
     * 🚨 **Anche lo scatto va bloccato in verticale, non solo lo schermo.**
     *
     * ⚠️ `setPreferredOrientations` tiene ferma l'interfaccia, ma il sensore
     * continua a sapere come è girato il telefono: senza questa riga, una foto
     * scattata con il telefono inclinato uscirebbe ruotata rispetto a quello
     * che si vedeva nell'anteprima.
     */
    await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
    await c.setFlashMode(_flash);

    if (!mounted) {
      await c.dispose();

      return;
    }

    setState(() {
      _controllore = c;
      _quale = indice;
      _guasto = null;
    });
  }

  Future<void> _scatta() async {
    final c = _controllore;

    if (c == null || _scattando) return;

    setState(() => _scattando = true);

    try {
      final scatto = await c.takePicture();

      /*
       * 🚨 **Ritaglio al centro: lo specchio esatto di come si vede.**
       *
       * L'anteprima sopra sta dentro un quadrato che mostra il centro del
       * fotogramma; qui si tiene il centro dei pixel. ⚠️ Se un giorno
       * l'anteprima cambiasse inquadratura senza che cambi anche questo, la
       * promessa «quello che vedi è quello che salvi» salterebbe **in
       * silenzio**: nessun test lo direbbe, e lo scoprirebbe qualcuno con una
       * foto tagliata male.
       */
      final ritagliata = await ritagliaQuadrato(byte: await scatto.readAsBytes());

      if (!mounted) return;

      if (ritagliata == null) {
        setState(() {
          _scattando = false;
          _guasto = 'Questo scatto non sono riuscito a leggerlo. Riprova.';
        });

        return;
      }

      Navigator.of(context).pop(ritagliata);
    } on CameraException {
      if (!mounted) return;

      setState(() {
        _scattando = false;
        _guasto = 'Lo scatto non è riuscito. Riprova.';
      });
    }
  }

  /// 💡 Tre stati e non due: «automatico» è quello che serve quasi sempre, ma
  /// va potuto **spegnere** — in palestra davanti a uno specchio il flash
  /// rimbalza e rovina la foto — e **accendere** a forza quando l'automatico
  /// sbaglia.
  Future<void> _cambiaFlash() async {
    const giro = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final prossimo = giro[(giro.indexOf(_flash) + 1) % giro.length];

    try {
      await _controllore?.setFlashMode(prossimo);

      if (mounted) setState(() => _flash = prossimo);
    } on CameraException {
      // 💡 Ci sono fotocamere senza flash — quella frontale, quasi sempre. Non
      // è un errore da mostrare: semplicemente non cambia niente.
    }
  }

  Future<void> _giraFotocamera() async {
    if (_fotocamere.length < 2) return;

    await _accendi((_quale + 1) % _fotocamere.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.titolo ?? 'Scatta'),
      ),
      body: SafeArea(
        child: _guasto != null
            ? _Guasto(messaggio: _guasto!, riprova: _avvia)
            : Column(
                children: [
                  Expanded(child: Center(child: _anteprima())),
                  _comandi(),
                ],
              ),
      ),
    );
  }

  Widget _anteprima() {
    final c = _controllore;

    if (c == null || !c.value.isInitialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    /*
     * ── 🚨 Il riquadro quadrato È l'inquadratura, non una decorazione ───────
     *
     * `AspectRatio(1)` + `ClipRect` + `BoxFit.cover` fanno vedere **il centro**
     * del fotogramma, esattamente il pezzo che `ritagliaQuadrato` terrà.
     *
     * ⚠️ Una maschera disegnata *sopra* un'anteprima intera avrebbe mostrato
     * anche quello che sta fuori, e chi compone tenderebbe a usarlo — salvo poi
     * ritrovarselo tagliato via.
     */
    return Padding(
      padding: const EdgeInsets.all(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: c.value.previewSize?.height ?? 1,
              height: c.value.previewSize?.width ?? 1,
              child: CameraPreview(c),
            ),
          ),
        ),
      ),
    );
  }

  Widget _comandi() {
    final acceso = _controllore?.value.isInitialized ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: acceso ? _cambiaFlash : null,
            icon: Icon(_iconaFlash, color: Colors.white, size: 28),
            tooltip: _nomeFlash,
          ),
          _BottoneScatto(
            onPressed: acceso && !_scattando ? _scatta : null,
            inCorso: _scattando,
          ),
          IconButton(
            onPressed: acceso && _fotocamere.length > 1 ? _giraFotocamera : null,
            icon: const Icon(
              Icons.flip_camera_ios_outlined,
              color: Colors.white,
              size: 28,
            ),
            tooltip: 'Gira la fotocamera',
          ),
        ],
      ),
    );
  }

  IconData get _iconaFlash => switch (_flash) {
    FlashMode.always => Icons.flash_on,
    FlashMode.auto => Icons.flash_auto,
    _ => Icons.flash_off,
  };

  String get _nomeFlash => switch (_flash) {
    FlashMode.always => 'Flash acceso',
    FlashMode.auto => 'Flash automatico',
    _ => 'Flash spento',
  };
}

class _BottoneScatto extends StatelessWidget {
  const _BottoneScatto({required this.onPressed, required this.inCorso});

  final VoidCallback? onPressed;
  final bool inCorso;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          color: onPressed == null ? Colors.white24 : Colors.white,
        ),
        child: inCorso
            ? const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : null,
      ),
    );
  }
}

class _Guasto extends StatelessWidget {
  const _Guasto({required this.messaggio, required this.riprova});

  final String messaggio;
  final VoidCallback riprova;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(
              messaggio,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: riprova,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}
