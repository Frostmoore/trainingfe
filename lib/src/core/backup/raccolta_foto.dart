import 'dart:io';

import 'package:path/path.dart' as p;

import '../media/archivio_foto.dart';
import '../media/tipo_foto.dart';

/// L'inventario delle foto **che vanno salvate** — N5.1, riscritta in N12.1.
///
/// ── 💡 A cosa serve, prima di come funziona ────────────────────────────────
///
/// La spunta «salva anche le foto» non si può offrire al buio: mandare nel
/// proprio spazio su Drive qualche centinaio di megabyte è una decisione che si
/// prende **sapendo quanti sono**. Questa classe è quella che lo sa.
///
/// ── 🚨 Quali cartelle guarda, e perché non lo decide lei ───────────────────
///
/// Guarda i tipi con `nelBackup: true`, e basta. ⚠️ Fino alla `v7.5.0` qui
/// c'era **una cartella sola**, scritta a mano: con l'arrivo di `chat`,
/// `ai`, `alimenti` ed `effimere` una lista tenuta qui sarebbe stata la cosa
/// che ci si dimentica di aggiornare, e le foto di un tipo nuovo sarebbero
/// restate fuori dal backup **in silenzio**.
///
/// 💡 La domanda «va salvata?» si risponde una volta sola, su [TipoFoto].
class RaccoltaFoto {
  const RaccoltaFoto({this.archivio = const ArchivioFoto()});

  final ArchivioFoto archivio;

  /// 🚨 Solo immagini, e l'elenco è **di ammessi**.
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

  /// Le foto da salvare, ordinate per tipo e poi per nome.
  ///
  /// 💡 Ordinate e non nell'ordine del filesystem: così due telefoni diversi
  /// producono lo stesso elenco, e i confronti fra locale e cloud sono stabili.
  Future<List<FotoDaSalvare>> elenca() async {
    final trovate = <FotoDaSalvare>[];

    for (final tipo in TipoFoto.daSalvare) {
      final cartella = await archivio.cartellaDi(tipo);

      if (!cartella.existsSync()) continue;

      for (final voce in await cartella.list().toList()) {
        if (voce is! File) continue;
        if (!ammessa(voce.path)) continue;

        trovate.add(FotoDaSalvare(tipo: tipo, file: voce));
      }
    }

    trovate.sort((a, b) => a.nomeNelCloud.compareTo(b.nomeNelCloud));

    return trovate;
  }

  /// Quanto pesano in tutto, in byte.
  Future<int> byteTotali() async {
    var somma = 0;

    for (final f in await elenca()) {
      somma += await f.file.length();
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

/// Una foto che va nel backup, con il tipo che le dice dove tornare.
class FotoDaSalvare {
  const FotoDaSalvare({required this.tipo, required this.file});

  final TipoFoto tipo;
  final File file;

  String get nome => p.basename(file.path);

  /// ── 🚨 Il nome nel cloud porta con sé il tipo ───────────────────────────
  ///
  /// Il cloud è **piatto**: non ha cartelle, solo nomi. ⚠️ Salvando il solo
  /// nome del file, al ripristino non si saprebbe più se quella foto era un
  /// progresso o una chat, e finirebbero tutte nello stesso mucchio.
  ///
  /// 💡 Il separatore è `~` e non `/`: le interrogazioni a Drive filtrano per
  /// nome, e una barra dentro un nome è la cosa che prima o poi qualcuno prova
  /// a interpretare come percorso.
  String get nomeNelCloud => '${tipo.cartella}$separatore$nome';

  static const separatore = '~';

  /// Il tipo e il nome dentro un nome del cloud, o `null` se non si capisce.
  ///
  /// ⚠️ **Il nome arriva dal cloud, quindi non ci si fida.** Si accettano solo
  /// tipi che vanno davvero nel backup, e il nome passa da `basename`: senza,
  /// un allegato chiamato `progressi~../../fuori.jpg` scriverebbe fuori dalla
  /// cartella delle foto.
  static ({TipoFoto tipo, String nome})? leggi(String nomeNelCloud) {
    final taglio = nomeNelCloud.indexOf(separatore);

    if (taglio <= 0) return null;

    final tipo = TipoFoto.dallaCartella(nomeNelCloud.substring(0, taglio));

    if (tipo == null || !tipo.nelBackup) return null;

    final nome = p.basename(nomeNelCloud.substring(taglio + 1));

    if (nome.isEmpty || !RaccoltaFoto.ammessa(nome)) return null;

    return (tipo: tipo, nome: nome);
  }
}
