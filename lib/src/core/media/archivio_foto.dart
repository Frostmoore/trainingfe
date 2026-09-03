import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tipo_foto.dart';

/// Dove vivono le foto, e chi le butta — N9.3.
///
/// ── 🚨 Il percorso salvato è RELATIVO, sempre ──────────────────────────────
///
/// Su iOS il contenitore dell'app **cambia percorso a ogni aggiornamento**: un
/// percorso assoluto scritto oggi domani punta al nulla, e la galleria di
/// qualcuno si svuoterebbe da sola senza che nessuno abbia cancellato niente.
///
/// 💡 La forma è `foto/<cartella>/<nome>`, e la cartella basta a ritrovare la
/// radice: da lì si risale al [TipoFoto], e dal tipo si sa se sta nei documenti
/// o nella cache.
class ArchivioFoto {
  const ArchivioFoto();

  /// 🚨 Il nome della cartella madre è **lo stesso di prima della `v7.4.0`**
  /// (`foto`), e non per pigrizia: le regole di N0 in
  /// `android/app/src/main/res/xml/data_extraction_rules.xml` escludono
  /// `root/foto` dal backup di sistema. È un **prefisso**, quindi le
  /// sottocartelle nuove sono già coperte. ⚠️ Cambiando questo nome quelle
  /// regole smetterebbero di valere in silenzio, e le foto tornerebbero a
  /// sfondare il tetto dei 25 MB facendo fallire il backup di tutto il resto.
  static const madre = 'foto';

  /// Distingue due salvataggi nello stesso millisecondo. Vedi [salva].
  static int _progressivo = 0;

  /// La cartella di un tipo, creata se non c'è.
  Future<Directory> cartellaDi(TipoFoto tipo) async {
    final radice = tipo.permanente
        ? await getApplicationDocumentsDirectory()
        : await getApplicationCacheDirectory();

    final dir = Directory(p.join(radice.path, madre, tipo.cartella));

    if (!dir.existsSync()) await dir.create(recursive: true);

    return dir;
  }

  /// Scrive i byte e torna il percorso **relativo** da salvare a database.
  ///
  /// ══ 🚨 `estensione` NON E' UN DETTAGLIO COSMETICO — K1-bis, 03/09/2026 ═══
  ///
  /// ⛔ Fino al 03/09 il nome finiva **sempre** in `.jpg`. Per le foto andava
  /// bene, ma la revisione dei piani importati salvava di qui il **PDF
  /// originale**: finiva sul disco chiamato `.jpg`, e `OpenFilex` lo apriva —
  /// o meglio non lo apriva — con un visualizzatore di immagini.
  ///
  /// 🚨 Nessun errore da nessuna parte: il file c'era, il percorso era giusto,
  /// il database era coerente. Semplicemente il pulsante *«vedi l'originale»* —
  /// cioe' l'unica cosa che rende una revisione una revisione — non mostrava
  /// niente.
  ///
  /// ⚠️ Il valore di partenza resta `jpg` perche' e' quello che vale per tutte
  /// le foto, che sono la quasi totalita' dei chiamanti.
  Future<String> salva({
    required TipoFoto tipo,
    required Uint8List byte,
    String estensione = 'jpg',
  }) async {
    final cartella = await cartellaDi(tipo);

    /*
     * ── 🚨 L'ora NON basta a fare un nome unico ─────────────────────────
     *
     * Qui c'era scritto che i microsecondi risolvevano le collisioni. ⚠️ **E'
     * falso**: `DateTime.now()` ha risoluzione al **millisecondo** su parecchie
     * piattaforme, e i microsecondi sono zeri messi li' per riempire. Due
     * salvataggi di fila — lo scatto rapido, o una foto ricevuta mentre se ne
     * salva un'altra — producevano lo **stesso nome**, e la seconda prendeva il
     * posto della prima **senza nessun errore**.
     *
     * 💡 Il progressivo chiude il buco: nello stesso millisecondo i nomi
     * restano diversi comunque. Non serve che sopravviva al riavvio dell'app —
     * lo distingue gia' l'ora.
     */
    /*
     * ⚠️ **Senza il punto e in minuscolo**, comunque arrivi: `p.extension()`
     * lo restituisce con il punto (`.PDF`), e concatenarlo cosi' com'e' darebbe
     * `...-0..PDF`.
     */
    final coda = estensione.replaceAll('.', '').toLowerCase();

    final nome =
        '${DateTime.now().microsecondsSinceEpoch}-${_progressivo++}.$coda';

    await File(p.join(cartella.path, nome)).writeAsBytes(byte);

    return p.url.join(madre, tipo.cartella, nome);
  }

  /// Rifà il percorso assoluto da quello relativo.
  ///
  /// ⚠️ Lancia se il relativo non ha la forma attesa: un percorso che non si sa
  /// risolvere è meglio scoprirlo qui che ritrovarsi un `File` che punta a una
  /// cartella a caso.
  Future<File> fileDi(String relativo) async {
    final pezzi = p.url.split(relativo);

    if (pezzi.length != 3 || pezzi.first != madre) {
      throw ArgumentError.value(
        relativo,
        'relativo',
        'Atteso "$madre/<cartella>/<nome>"',
      );
    }

    final tipo = TipoFoto.dallaCartella(pezzi[1]);

    if (tipo == null) {
      throw ArgumentError.value(relativo, 'relativo', 'Cartella sconosciuta');
    }

    return File(p.join((await cartellaDi(tipo)).path, pezzi[2]));
  }

  /// Butta una foto. Non è un errore se non c'era.
  Future<void> cancella(String relativo) async {
    final file = await fileDi(relativo);

    if (file.existsSync()) await file.delete();
  }

  /// Butta tutto quello che è scaduto — N11.6.
  ///
  /// ── ⚠️ Perché serve, e perché va chiamata in più di un posto ─────────────
  ///
  /// L'app può morire fra lo scatto di una foto per il modello e la conferma
  /// dell'alimento: quell'orfano non lo cancellerebbe più nessuno. E le 24 ore
  /// di una foto effimera scadono **anche ad app chiusa**, quindi un solo punto
  /// di pulizia non le prenderebbe.
  ///
  /// 💡 Va chiamata all'avvio **e** all'apertura di una conversazione. Se
  /// qualcuno non apre l'app per una settimana quei file restano lì — ma stanno
  /// nella cache, quindi non finiscono in nessun backup e spariscono al primo
  /// avvio successivo. È il compromesso, ed è consapevole.
  ///
  /// @return quante ne ha buttate.
  Future<int> spazzaGliOrfani() async {
    var buttate = 0;
    final adesso = DateTime.now();

    for (final tipo in TipoFoto.cheScadono) {
      final cartella = await cartellaDi(tipo);

      /*
       * 🚨 **Si raccoglie tutto PRIMA di cancellare.**
       *
       * ⚠️ Cancellare dentro `await for (… in cartella.list())` vuol dire
       * modificare la cartella mentre la si sta ancora leggendo: il sistema
       * puo' saltare le voci successive. Con un file solo non si vede — il
       * difetto si presenta dal secondo in poi, ed e' esattamente cosi' che si
       * e' fatto vedere in `archivio_foto_test.dart`.
       */
      final voci = await cartella.list().toList();

      for (final voce in voci) {
        if (voce is! File) continue;

        /*
         * ⚠️ Si guarda la data di **modifica** del file, non quella nel nome.
         *
         * 💡 Il nome contiene sì il momento della creazione, ma è una nostra
         * convenzione: un file arrivato in altro modo — o rinominato — non
         * l'avrebbe, e resterebbe lì per sempre. La data del filesystem c'è
         * comunque.
         */
        final quando = await voce.lastModified();

        if (adesso.difference(quando) < tipo.scadenza!) continue;

        await voce.delete();
        buttate++;
      }
    }

    return buttate;
  }
}
