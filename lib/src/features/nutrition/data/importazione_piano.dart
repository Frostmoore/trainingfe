import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';

/// L'importazione di un piano alimentare da PDF — N20.
///
/// ── 🚨 Quello che arriva NON è un piano, è una trascrizione ───────────────
///
/// Il piano l'ha scritto un professionista abilitato ed è dentro il PDF. Questo
/// è il tentativo dell'AI di ricopiarlo in una struttura, e finché qualcuno non
/// lo ha guardato riga per riga con l'originale accanto (N20.3) **non vale
/// niente**.
///
/// ⚠️ Il rischio non è che l'AI fallisca — un fallimento si vede e si rifà. È
/// che riesca **a metà**: «200 g» letti «20 g» non danno nessun errore, danno
/// un piano credibile e sbagliato, che qualcuno seguirà per settimane.
@immutable
class ImportazionePiano {
  const ImportazionePiano({
    required this.id,
    required this.stato,
    required this.nomeFile,
    required this.righe,
    this.bozza,
    this.errore,
  });

  factory ImportazionePiano.fromJson(Map<String, dynamic> json) => ImportazionePiano(
    id: (json['id'] as num).toInt(),
    stato: StatoImportazione.da(json['stato']?.toString()),
    nomeFile: json['nome_file']?.toString() ?? 'piano.pdf',
    righe: (json['righe'] as num?)?.toInt() ?? 0,
    bozza: (json['bozza'] as Map?)?.cast<String, dynamic>(),
    errore: json['errore']?.toString(),
  );

  final int id;
  final StatoImportazione stato;
  final String nomeFile;

  /// Quante righe di alimento ci sono da controllare.
  ///
  /// 💡 Si mostra **prima** di aprire la revisione: «34 righe da confrontare
  /// con l'originale» è un'informazione che cambia come qualcuno la affronta.
  /// Chi crede che sia questione di due secondi la fa male.
  final int righe;

  final Map<String, dynamic>? bozza;
  final String? errore;

  /// Quello che il modello ha dichiarato di non aver letto bene.
  ///
  /// 🚨 **È la parte più utile della risposta.** Porta chi controlla dritto
  /// sulle righe che contano: senza, la revisione è un elenco di trenta voci
  /// tutte uguali, e chi la fa si stanca alla decima — proprio prima di
  /// arrivare a quella sbagliata.
  List<String> get dubbi =>
      ((bozza?['dubbi'] as List?) ?? const []).map((e) => e.toString()).toList();

  String get nome => bozza?['nome']?.toString() ?? 'Piano importato';

  double get confidenza => (bozza?['confidenza'] as num?)?.toDouble() ?? 0;

  bool get inLavorazione =>
      stato == StatoImportazione.inCoda || stato == StatoImportazione.inLavorazione;
}

enum StatoImportazione {
  inCoda,
  inLavorazione,
  pronta,
  fallita;

  static StatoImportazione da(String? valore) => switch (valore) {
    'in_lavorazione' => StatoImportazione.inLavorazione,
    'pronta' => StatoImportazione.pronta,
    'fallita' => StatoImportazione.fallita,
    _ => StatoImportazione.inCoda,
  };
}

/// Le chiamate al server per importare un piano.
class ImportazioniPiani {
  const ImportazioniPiani(this._api);

  final ApiClient _api;

  /// Carica il PDF e mette in coda la trascrizione.
  ///
  /// 🚨 `dichiarazione` non ha un default: chi importa **deve** dichiarare che
  /// il piano l'ha redatto un professionista abilitato, e un parametro
  /// facoltativo sarebbe il primo posto dove quella dichiarazione si perde.
  Future<ImportazionePiano> carica({
    required Uint8List byte,
    required String nomeFile,
    required bool dichiarazione,
  }) async {
    final risposta = await _api.upload<Map<String, dynamic>>(
      '/importazioni-piani',
      FormData.fromMap({
        'file': MultipartFile.fromBytes(byte, filename: nomeFile),
        'dichiarazione': dichiarazione ? '1' : '0',
      }),
    );

    return ImportazionePiano.fromJson(risposta);
  }

  Future<ImportazionePiano> stato(int id) async {
    final risposta = await _api.get<Map<String, dynamic>>('/importazioni-piani/$id');

    return ImportazionePiano.fromJson(risposta);
  }

  /// Il PDF originale, per guardarlo accanto alla bozza — N20.4.
  Future<Uint8List> pdf(int id) => _api.scaricaByte('/importazioni-piani/$id/pdf');

  /// Chiude l'importazione: il PDF e la bozza se ne vanno dal server.
  ///
  /// 🚨 **Si chiama sia dopo aver confermato sia dopo aver scartato.** Il piano
  /// confermato non resta sul server: se lo tenessimo avremmo una dieta legata
  /// a una persona sui loro sistemi, cioè un dato dell'art. 9 con un nome
  /// sopra. Il telefono se la porta via, e la riga si cancella.
  Future<void> chiudi(int id) => _api.delete('/importazioni-piani/$id');
}

final importazioniPianiProvider = Provider<ImportazioniPiani>(
  (ref) => ImportazioniPiani(ref.watch(apiClientProvider)),
);
