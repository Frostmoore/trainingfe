import 'dart:io';

import 'package:path/path.dart' as p;

/// L'inventario delle foto sul telefono — N5.1.
///
/// ── 💡 A cosa serve, prima di come funziona ────────────────────────────────
///
/// La spunta «salva anche le foto» non si può offrire al buio: mandare nel
/// proprio spazio su Drive qualche centinaio di megabyte è una decisione che si
/// prende **sapendo quanti sono**. Questa classe è quella che lo sa.
class RaccoltaFoto {
  const RaccoltaFoto(this.cartella);

  /// La cartella `Documents/foto`, la stessa di `progress_controller.dart`.
  final Directory cartella;

  /// ── 🚨 Solo immagini, e l'elenco è una lista di ammessi ─────────────────
  ///
  /// **N5.3: i video non entrano mai nel backup automatico.** ⚠️ È scritto come
  /// elenco di ciò che passa e non di ciò che si scarta, perché le due forme
  /// sbagliano in direzioni opposte: un elenco di esclusi lascia passare il
  /// formato a cui nessuno aveva pensato — e nel caso dei video quel formato
  /// pesa cento volte una foto, sul piano dati di qualcun altro.
  static const estensioniAmmesse = <String>{
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
  };

  /// Le foto presenti, ordinate per nome.
  ///
  /// 💡 Ordinate e non nell'ordine del filesystem: così due telefoni diversi
  /// producono lo stesso elenco, e i confronti fra locale e cloud sono stabili.
  Future<List<File>> elenca() async {
    if (!cartella.existsSync()) return const [];

    final trovate = <File>[];

    await for (final voce in cartella.list()) {
      if (voce is! File) continue;
      if (!ammessa(voce.path)) continue;

      trovate.add(voce);
    }

    trovate.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    return trovate;
  }

  /// Quanto pesano in tutto, in byte.
  Future<int> byteTotali() async {
    var somma = 0;

    for (final f in await elenca()) {
      somma += await f.length();
    }

    return somma;
  }

  /// 💡 Un file è una foto se lo dice **l'estensione**, minuscola o maiuscola.
  static bool ammessa(String percorso) =>
      estensioniAmmesse.contains(p.extension(percorso).toLowerCase());

  /// «240 MB», «1,4 GB», «856 kB» — da mostrare accanto alla spunta.
  ///
  /// ⚠️ In base 1000 e non 1024: è la scala con cui Android e Google Drive
  /// mostrano lo spazio, e far leggere due numeri diversi per la stessa cosa è
  /// il modo per farla sembrare sbagliata.
  static String pesoLeggibile(int byte) {
    if (byte < 1000) return '$byte byte';

    const unita = ['kB', 'MB', 'GB', 'TB'];
    var valore = byte / 1000;
    var i = 0;

    while (valore >= 1000 && i < unita.length - 1) {
      valore /= 1000;
      i++;
    }

    // 💡 Un decimale sotto il 10, nessuno sopra: «1,4 GB» dice qualcosa,
    // «847,3 MB» è precisione che nessuno userà per decidere.
    final testo = valore < 10
        ? valore.toStringAsFixed(1).replaceAll('.', ',')
        : valore.round().toString();

    return '$testo ${unita[i]}';
  }
}
