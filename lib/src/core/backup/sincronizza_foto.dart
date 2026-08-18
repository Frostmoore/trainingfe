import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../crypto/file_di_backup.dart';
import 'cloud_di_backup.dart';
import 'raccolta_foto.dart';

/// Porta le foto nel cloud e le riprende — N5.
///
/// ── 💡 Incrementale, e questa è tutta la ragione per cui esiste ────────────
///
/// L'archivio si rifà da capo ogni volta perché pesa qualche decina di
/// kilobyte. Le foto no: si carica **solo la differenza** fra quello che c'è
/// sul telefono e quello che c'è già nel cloud. Un backup giornaliero che
/// ricaricasse duecento megabyte ogni notte verrebbe spento dopo tre giorni, e
/// avrebbe ragione chi lo spegne.
class SincronizzaFoto {
  const SincronizzaFoto({
    required this.cloud,
    required this.backup,
    required this.raccolta,
    required this.chiaveMaestra,
  });

  final CloudDiBackup cloud;
  final FileDiBackup backup;
  final RaccoltaFoto raccolta;
  final Uint8List chiaveMaestra;

  /// Carica le foto che nel cloud non ci sono ancora.
  ///
  /// @return quante ne ha caricate.
  Future<int> caricaLeNuove() async {
    final gia = await cloud.elencaAllegati();
    final locali = await raccolta.elenca();

    var caricate = 0;

    for (final file in locali) {
      final nome = p.basename(file.path);

      if (gia.contains(nome)) continue;

      final cifrata = await backup.cifraFoto(
        chiaveMaestra: chiaveMaestra,
        contenuto: await file.readAsBytes(),
      );

      await cloud.caricaAllegato(nome, cifrata);
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

    if (!raccolta.cartella.existsSync()) {
      await raccolta.cartella.create(recursive: true);
    }

    final locali = {
      for (final f in await raccolta.elenca()) p.basename(f.path),
    };

    var riprese = 0;

    for (final nome in nelCloud) {
      if (locali.contains(nome)) continue;

      /*
       * ⚠️ **Il nome viene dal cloud, quindi non ci si fida.** `basename` toglie
       * qualunque parte di percorso: senza, un allegato chiamato
       * `../../qualcosa` scriverebbe fuori dalla cartella delle foto. Non è un
       * attacco probabile — è il nostro stesso file — ma è la riga che fa la
       * differenza fra «non può succedere» e «non è successo per fortuna».
       */
      final sicuro = p.basename(nome);

      if (sicuro.isEmpty || !RaccoltaFoto.ammessa(sicuro)) continue;

      final cifrata = await cloud.scaricaAllegato(nome);

      if (cifrata == null) continue;

      final chiara = await backup.decifraFoto(
        chiaveMaestra: chiaveMaestra,
        contenuto: cifrata,
      );

      await File(p.join(raccolta.cartella.path, sicuro)).writeAsBytes(chiara);
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
