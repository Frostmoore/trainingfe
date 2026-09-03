/// Scegliere i documenti da importare, e **tenerseli** — Parte K, K1-bis.
///
/// ══ 🚨 LA COPIA LOCALE SI FA QUI, PRIMA DI CARICARE ═══════════════════════
///
/// 📌 Il committente, il 03/09/2026: *«Naturalmente niente deve stare più sul
/// server, come avevamo detto»*.
///
/// ⛔ Prima il PDF restava di là **sette giorni**, e la revisione se lo faceva
/// riconsegnare per mostrarlo accanto alla bozza. 🚨 Quella ragione resta vera —
/// una revisione senza l'originale accanto non è una revisione, è la lettura di
/// trenta numeri plausibili — ma il documento **ce l'ha già il telefono**, che è
/// chi l'ha scelto.
///
/// ⚠️ **Quindi la copia si fa nel momento della scelta, non dopo.** Farla dopo
/// vorrebbe dire che un guasto fra il caricamento e la revisione lascia la
/// persona con una bozza e senza niente con cui confrontarla — e i gettoni
/// già spesi.
///
/// ══ ⚠️ E FINISCE NEL BACKUP ═══════════════════════════════════════════════
///
/// 📌 *«Ogni volta che abbiamo un nuovo dato o un nuovo file, questo deve
/// comunque finire in qualche modo nel backup»*. `TipoFoto.piani` è permanente
/// e nel backup: il documento è l'unica copia che esiste al mondo, e si è pagato
/// per farselo scrivere.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../core/media/archivio_foto.dart';
import '../../../core/media/tipo_foto.dart';
import 'origine_della_bozza.dart';

/// Un documento scelto, **già copiato in casa**.
@immutable
class DocumentoScelto {
  const DocumentoScelto({
    required this.relativo,
    required this.nome,
    required this.byte,
  });

  /// Il percorso **relativo** dentro `Documents/foto/piani`.
  ///
  /// ⚠️ Relativo e non assoluto: la cartella dei documenti cambia a ogni
  /// reinstallazione su iOS, e un percorso assoluto salvato oggi punta al vuoto
  /// domani.
  final String relativo;

  /// Il nome originale, con l'estensione vera.
  ///
  /// 🚨 **Serve al server per capire cos'è**, ma non è lui a deciderlo: di là il
  /// tipo si legge dai byte con `finfo`, perché un nome si scrive a mano.
  final String nome;

  /// I byte, da caricare.
  ///
  /// 💡 Si tengono in memoria solo il tempo del caricamento: cinque pagine
  /// fotografate sono al massimo 40 MB, e rileggerli dal disco vorrebbe dire un
  /// secondo modo di sbagliare il percorso.
  final Uint8List byte;
}

/// Il risultato della scelta.
@immutable
class DocumentiScelti {
  const DocumentiScelti({required this.documenti, required this.tipo});

  final List<DocumentoScelto> documenti;

  /// 🚨 **Deciso dall'estensione del primo file**, e serve solo a mostrare
  /// l'avvertenza giusta prima di caricare. ⚠️ Quello che conta davvero lo
  /// decide il server guardando i byte.
  final TipoDiDocumento tipo;

  int get quanti => documenti.length;

  int get byteTotali =>
      documenti.fold(0, (somma, d) => somma + d.byte.lengthInBytes);
}

/// Sceglie i documenti e ne fa una copia locale.
class SceltaDeiDocumenti {
  const SceltaDeiDocumenti({
    this.archivio = const ArchivioFoto(),
    this.fotocamera,
  });

  final ArchivioFoto archivio;

  /// ⚠️ Iniettabile e `null` di partenza: `ImagePicker()` non è `const`, e un
  /// valore di default lo renderebbe impossibile — questa classe si costruisce
  /// `const` dentro lo stato della schermata.
  final ImagePicker? fotocamera;

  /// ⛔ **`heic` non c'è**, e non è una dimenticanza: Anthropic non lo accetta,
  /// e lasciarlo passare darebbe un rifiuto del fornitore che a chi guarda
  /// arriva come *«l'AI non è disponibile»*.
  static const estensioni = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];

  /// 🚨 **Al massimo cinque**, come il server. ⚠️ Il limite è scritto in due
  /// posti e non può essere altrimenti — sono due programmi — ma qui si ferma
  /// **prima** di caricare: scoprirlo dal server vorrebbe dire aver già mandato
  /// sei documenti sanitari per sentirsi dire di no.
  static const alMassimo = 5;

  /// Sceglie dai file: PDF o immagini, fino a cinque.
  Future<DocumentiScelti?> daiFile() async {
    // 📌 `FilePicker.platform` e non i metodi statici: siamo fermi alla 10.x.
    final scelta = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: estensioni,
      allowMultiple: true,
      withData: true,
    );

    final file = scelta?.files ?? const <PlatformFile>[];

    if (file.isEmpty) return null;

    final documenti = <DocumentoScelto>[];

    for (final f in file.take(alMassimo)) {
      final byte = f.bytes;

      if (byte == null) continue;

      documenti.add(await _riponi(byte: byte, nome: f.name));
    }

    if (documenti.isEmpty) return null;

    return DocumentiScelti(documenti: documenti, tipo: _tipoDi(documenti));
  }

  /// Scatta una foto e la aggiunge a quelle già scelte.
  ///
  /// ⚠️ **Una per volta, e si torna qui**: `image_picker` non fa scatti
  /// multipli, e fingere il contrario con un ciclo che riapre la fotocamera
  /// toglierebbe la possibilità di fermarsi dopo la seconda pagina.
  Future<DocumentoScelto?> unoScatto() async {
    final scatto = await (fotocamera ?? ImagePicker()).pickImage(
      source: ImageSource.camera,

      /*
       * ⚠️ **Non si comprime e non si ridimensiona.** Una scheda scritta a mano
       * si legge per i dettagli — un 3 che potrebbe essere un 8 — ed è
       * esattamente quello che una compressione porta via. 🚨 Il tetto dei byte
       * lo controlla chi chiama, dopo.
       */
      imageQuality: 100,
    );

    if (scatto == null) return null;

    return _riponi(byte: await scatto.readAsBytes(), nome: scatto.name);
  }

  /// 💡 `jpg` quando il nome non dice niente: un file senza estensione che
  /// arriva dalla fotocamera è una fotografia, e chiamarlo `bin` darebbe un
  /// documento che nessuna applicazione del telefono sa aprire.
  Future<DocumentoScelto> _riponi({
    required Uint8List byte,
    required String nome,
  }) async {
    final estensione = p.extension(nome).replaceAll('.', '').toLowerCase();

    final relativo = await archivio.salva(
      tipo: TipoFoto.piani,
      byte: byte,
      estensione: estensioni.contains(estensione) ? estensione : 'jpg',
    );

    return DocumentoScelto(relativo: relativo, nome: nome, byte: byte);
  }

  /// 🚨 **Basta un PDF perché sia un PDF.** ⚠️ Il caso misto — un PDF e due
  /// fotografie — è raro ma possibile, e mostrare l'avvertenza sulle immagini
  /// quando c'è anche un PDF è meno grave del contrario: un avviso in più si
  /// legge, uno in meno no.
  TipoDiDocumento _tipoDi(List<DocumentoScelto> documenti) =>
      documenti.every((d) => p.extension(d.nome).toLowerCase() == '.pdf')
          ? TipoDiDocumento.pdf
          : TipoDiDocumento.immagini;
}
