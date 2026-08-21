import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../crypto/file_di_backup.dart';
import '../media/archivio_foto.dart';
import 'cloud_di_backup.dart';
import 'raccolta_foto.dart';

/// Porta le foto nel cloud e le riprende — N5, riscritta in N12.1.
///
/// ── 💡 Incrementale, e questa è tutta la ragione per cui esiste ────────────
///
/// L'archivio si rifà da capo ogni volta perché pesa qualche decina di
/// kilobyte. Le foto no: si carica **solo la differenza** fra quello che c'è
/// sul telefono e quello che c'è già nel cloud. Un backup giornaliero che
/// ricaricasse duecento megabyte ogni notte verrebbe spento dopo tre giorni, e
/// avrebbe ragione chi lo spegne.
///
/// ── 🚨 Il tipo viaggia col nome ────────────────────────────────────────────
///
/// Il cloud è piatto: non ha cartelle, solo nomi. Ogni allegato si chiama
/// `<cartella>~<nome>`, così al ripristino si sa in quale cartella rimetterlo.
/// ⚠️ Salvando il solo nome del file, progressi e chat tornerebbero tutti nello
/// stesso mucchio.
class SincronizzaFoto {
  const SincronizzaFoto({
    required this.cloud,
    required this.backup,
    required this.chiaveMaestra,
    this.raccolta = const RaccoltaFoto(),
    this.archivio = const ArchivioFoto(),
  });

  final CloudDiBackup cloud;
  final FileDiBackup backup;
  final RaccoltaFoto raccolta;
  final ArchivioFoto archivio;
  final Uint8List chiaveMaestra;

  /// Carica le foto che nel cloud non ci sono ancora.
  ///
  /// @return quante ne ha caricate.
  Future<int> caricaLeNuove() async {
    final gia = await cloud.elencaAllegati();

    var caricate = 0;

    for (final foto in await raccolta.elenca()) {
      if (gia.contains(foto.nomeNelCloud)) continue;

      final cifrata = await backup.cifraFoto(
        chiaveMaestra: chiaveMaestra,
        contenuto: await foto.file.readAsBytes(),
      );

      await cloud.caricaAllegato(foto.nomeNelCloud, cifrata);
      caricate++;
    }

    return caricate;
  }

  /// Riprende dal cloud le foto che su questo telefono non ci sono.
  ///
  /// @return quante ne ha rimesse a posto.
  Future<int> riprendiLeMancanti() async {
    final nelCloud = await cloud.elencaAllegati();

    if (nelCloud.isEmpty) return 0;

    final locali = {for (final f in await raccolta.elenca()) f.nomeNelCloud};

    var riprese = 0;

    for (final nomeNelCloud in nelCloud) {
      if (locali.contains(nomeNelCloud)) continue;

      /*
       * ⚠️ **Il nome arriva dal cloud, quindi non ci si fida.**
       *
       * `FotoDaSalvare.leggi` accetta solo tipi che vanno davvero nel backup e
       * passa il nome da `basename`: senza, un allegato chiamato
       * `progressi~../../fuori.jpg` scriverebbe fuori dalla cartella delle
       * foto. Non è l'attacco più probabile — quel file lo abbiamo scritto noi
       * — ma è la riga che fa la differenza fra «non può succedere» e «non è
       * successo per fortuna».
       */
      final letto = FotoDaSalvare.leggi(nomeNelCloud);

      if (letto == null) continue;

      final cifrata = await cloud.scaricaAllegato(nomeNelCloud);

      if (cifrata == null) continue;

      final chiara = await backup.decifraFoto(
        chiaveMaestra: chiaveMaestra,
        contenuto: cifrata,
      );

      final cartella = await archivio.cartellaDi(letto.tipo);

      await File(p.join(cartella.path, letto.nome)).writeAsBytes(chiara);
      riprese++;
    }

    return riprese;
  }

  // ── 🚨 Quello che questa classe NON fa, e perché ─────────────────────────
  //
  // **Non cancella dal cloud le foto sparite dal telefono.** Sarebbe la terza
  // metà ovvia della sincronizzazione, ed è proprio quella da non scrivere:
  // su un telefono appena installato l'elenco locale è **vuoto**, e una
  // sincronizzazione simmetrica leggerebbe quel vuoto come «le ha cancellate
  // tutte» — svuotando il cloud un istante prima di ripristinarlo.
  //
  // 💡 Chi vuole liberare spazio ha già «spegni e cancella», che è esplicito.
}
