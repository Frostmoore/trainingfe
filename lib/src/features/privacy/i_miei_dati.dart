import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/providers.dart';
import '../health/health_controller.dart';

/// 📦 **«Scarica i miei dati»** — artt. 15 e 20 GDPR, 19/09/2026.
///
/// Un file solo, **leggibile**, con tutto: quello che sa il server
/// (`GET /account/export`) e quello che sta sul telefono (l'archivio locale).
///
/// ── 💡 Perché non il file di backup ────────────────────────────────────────
///
/// Il backup è **cifrato** e fatto per essere ripristinato da questa app: per
/// l'art. 20 serve un formato «strutturato, di uso comune e leggibile da
/// dispositivo automatico». Qui è JSON in chiaro, indentato.
///
/// 🚨 **In chiaro vuol dire che chi trova il file lo legge.** La schermata lo
/// dice prima del pulsante. ⚠️ Chiavi, token e codici non ci sono: il server li
/// toglie dalla sua parte, e l'archivio locale non ne contiene (le chiavi stanno
/// nel portachiavi del sistema, non nel database).
///
/// ⚠️ **I messaggi non ci sono**: sul server sono buste cifrate che nessuno sa
/// aprire, e sul telefono non si conservano. Il server esporta a chi e quando
/// li hai mandati.

/// Il file finale, a partire dalle due metà. Pura, per poterla provare.
Map<String, dynamic> componiIMieiDati({
  required Map<String, dynamic> dalServer,
  required Map<String, dynamic> dalTelefono,
  required DateTime quando,
}) => {
  'app': 'Training Companion',
  'formato': 1,
  'creato_il': quando.toIso8601String(),
  'cosa_contiene': {
    'server':
        'Quello che il server sa di te: account, palestra e '
        'trainer, consensi con data e ora, quando hai mandato i messaggi '
        '(non il testo, che è cifrato), consumi dell\'assistente AI.',
    'telefono':
        'Quello che sta solo su questo telefono: profilo, peso '
        'e misure, diario alimentare, allenamenti, sonno, esercizi e '
        'alimenti tuoi. Ogni chiave è una tabella dell\'archivio.',
  },
  'server': dalServer,
  'telefono': dalTelefono,
};

/// Il nome del file: con la data, così due esportazioni non si sovrascrivono.
String nomeDelFileDeiMieiDati(DateTime quando) {
  final g = quando.toIso8601String().substring(0, 10);

  return 'i-miei-dati-training-companion-$g.json';
}

final iMieiDatiProvider = Provider<IMieiDati>(IMieiDati.new);

class IMieiDati {
  IMieiDati(this._ref);

  final Ref _ref;

  /// Prepara il file e ne restituisce il percorso. ⚠️ Serve la rete: la metà
  /// del server si chiede adesso, non si tiene da parte.
  Future<File> prepara() async {
    final server = await _ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>('/account/export');
    final telefono = await _ref.read(archivioSaluteProvider).esportaPerBackup();
    final quando = DateTime.now();

    final cartella = await getTemporaryDirectory();
    final file = File('${cartella.path}/${nomeDelFileDeiMieiDati(quando)}');

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        componiIMieiDati(
          dalServer: server,
          dalTelefono: telefono,
          quando: quando,
        ),
      ),
    );

    return file;
  }
}
