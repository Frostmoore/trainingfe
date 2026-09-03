/// L'importazione di una scheda o di un piano da un documento — Parte K.
///
/// ══ 🚨 QUELLO CHE ARRIVA NON E' UNA SCHEDA, E' UNA TRASCRIZIONE ═══════════
///
/// Il documento l'ha scritto qualcun altro — un professionista abilitato, nel
/// caso della dieta — ed è dentro il file. Questo è il tentativo dell'AI di
/// ricopiarlo in una struttura, e finché qualcuno non lo ha guardato riga per
/// riga con l'originale accanto **non vale niente**.
///
/// ⚠️ Il rischio non è che l'AI fallisca — un fallimento si vede e si rifà. È
/// che riesca **a metà**: «200 g» letti «20 g» non danno nessun errore, danno
/// un piano credibile e sbagliato, che qualcuno seguirà per settimane.
///
/// ══ 🆕 E DAL 03/09 NON E' PIU' SOLO UN PDF, E NON E' PIU' SOLO UN PIANO ════
///
/// 📌 Il committente: *«l'import di pdf per le schede e per i piani alimentari
/// deve funzionare anche con le immagini»*.
///
/// 🚨 **Fino a cinque documenti**, che sono le pagine dello stesso foglio: una
/// scheda su carta sono spesso due o tre fotografie, e accettarne una sola
/// vorrebbe dire che chi ne fotografa una perde il resto **senza accorgersene**.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import 'documento_scelto.dart';
import 'origine_della_bozza.dart';

/// Cosa si sta importando.
///
/// 🚨 **Decide tre cose sul server**: quale funzione AI paga, quale prompt legge
/// il documento, e con quale schema esce la bozza. ⛔ Sbagliarlo non dà un
/// errore: dà una bozza vuota, letta con lo schema di un'altra cosa.
enum GenereImportato {
  piano('piano'),
  scheda('scheda');

  const GenereImportato(this.valore);

  final String valore;

  static GenereImportato da(String? v) =>
      v == 'scheda' ? GenereImportato.scheda : GenereImportato.piano;
}

@immutable
class ImportazioneDaDocumento {
  const ImportazioneDaDocumento({
    required this.id,
    required this.stato,
    required this.nomeFile,
    required this.righe,
    required this.tipo,
    required this.genere,
    required this.quantiDocumenti,
    this.bozza,
    this.errore,
  });

  factory ImportazioneDaDocumento.fromJson(Map<String, dynamic> json) =>
      ImportazioneDaDocumento(
        id: (json['id'] as num).toInt(),
        stato: StatoImportazione.da(json['stato']?.toString()),
        nomeFile: json['nome_file']?.toString() ?? 'documento',
        righe: (json['righe'] as num?)?.toInt() ?? 0,
        tipo: TipoDiDocumento.da(json['tipo']?.toString()),
        genere: GenereImportato.da(json['genere']?.toString()),
        quantiDocumenti: (json['quanti_documenti'] as num?)?.toInt() ?? 1,
        bozza: (json['bozza'] as Map?)?.cast<String, dynamic>(),
        errore: json['errore']?.toString(),
      );

  final int id;
  final StatoImportazione stato;
  final String nomeFile;

  /// Quante righe ci sono da controllare.
  ///
  /// 💡 Si mostra **prima** di aprire la revisione: «34 righe da confrontare con
  /// l'originale» è un'informazione che cambia come qualcuno la affronta. Chi
  /// crede che sia questione di due secondi la fa male.
  final int righe;

  /// `pdf` o `immagini`, deciso dal server **guardando i byte**.
  ///
  /// ⚠️ Non si deduce dal nome del file: un `.pdf` può essere qualunque cosa.
  final TipoDiDocumento tipo;

  final GenereImportato genere;
  final int quantiDocumenti;

  final Map<String, dynamic>? bozza;
  final String? errore;

  /// Quello che il modello ha dichiarato di non aver letto bene.
  ///
  /// ══ 🚨 E' LA PARTE PIU' UTILE DELLA RISPOSTA ═══════════════════════════
  ///
  /// Porta chi controlla dritto sulle righe che contano: senza, la revisione è
  /// un elenco di trenta voci tutte uguali, e chi la fa si stanca alla decima —
  /// proprio prima di arrivare a quella sbagliata.
  ///
  /// ══ ⚠️ PER LE SCHEDE NON C'E' UN CAMPO `dubbi`, E SI RICAVANO ══════════
  ///
  /// Il prompt delle schede non lo chiede: chiede una **confidenza per riga**, e
  /// dice al modello di scendere sotto 0.5 quando una cifra è anche solo
  /// possibilmente ambigua — «un 3 che potrebbe essere un 8».
  ///
  /// 💡 Quel numero, da solo, non lo legge nessuno. Qui diventa una frase, che è
  /// la forma in cui serve: 🚨 un segnale che esiste e non si vede è un segnale
  /// che non esiste.
  List<String> get dubbi {
    if (genere == GenereImportato.piano) {
      return ((bozza?['dubbi'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
    }

    final incerti = <String>[];

    for (final e in (bozza?['exercises'] as List?) ?? const []) {
      final riga = (e as Map).cast<String, dynamic>();
      final quanto = (riga['confidence'] as num?)?.toDouble() ?? 1;

      if (quanto < 0.5) {
        incerti.add(
          '«${riga['name'] ?? 'esercizio'}»: il modello non era sicuro di '
          'quello che c\'era scritto.',
        );
      }
    }

    return incerti;
  }

  /// Quello che il documento diceva **intorno** alle righe.
  ///
  /// ══ ⛔ NON E' UN DUBBIO, E PER UN GIORNO LO E' STATO ══════════════════
  ///
  /// La regola 7 del prompt dice al modello di segnalare nelle note le parti
  /// illeggibili che ha saltato, e da lì era sembrato naturale infilarle fra i
  /// dubbi. 🚨 **Su un documento vero il modello le usa per tutt'altro**: ci
  /// mette la frequenza settimanale, la durata della seduta, le regole di
  /// progressione — un paragrafo intero, su ogni import.
  ///
  /// ⛔ Finiva nel riquadro **rosso** dei «punti da guardare». Un avviso rosso
  /// che compare sempre e dice cose generiche insegna a saltare i riquadri
  /// rossi — e il giorno che ce n'è uno vero, nessuno lo legge.
  ///
  /// 💡 Quindi si mostra, perché è roba scritta sul foglio e buttarla sarebbe
  /// perdere informazione, ma **in chiaro e non in allarme**.
  String? get noteDelDocumento {
    final note = bozza?['notes']?.toString().trim() ?? '';

    return note.isEmpty ? null : note;
  }

  /// ⚠️ **`bozza ?? {}` e non `bozza?[...]`**, e non e' pignoleria: dentro un
  /// operatore ternario, `x?['chiave']` il parser di Dart lo legge come l'inizio
  /// di **un altro ternario** (`x ? [...] : ...`), e il file non compila piu'
  /// con un errore che non parla di niente di tutto questo.
  String get nome {
    final b = bozza ?? const <String, dynamic>{};

    final letto = (genere == GenereImportato.piano ? b['nome'] : b['name'])
            ?.toString()
            .trim() ??
        '';

    if (letto.isNotEmpty) return letto;

    return genere == GenereImportato.piano
        ? 'Piano importato'
        : 'Scheda importata';
  }

  /// Quanti giorni ha la scheda trascritta. `1` per tutto il resto.
  ///
  /// 🚨 Si legge **prima** della revisione: chi non è abbonato deve sapere che
  /// alla fine ne uscirà una per giorno, e scoprirlo dopo aver confrontato
  /// quaranta righe è il momento peggiore possibile.
  int get giorni => (bozza?['giorni'] as num?)?.toInt() ?? 1;

  bool get inLavorazione =>
      stato == StatoImportazione.inCoda ||
      stato == StatoImportazione.inLavorazione;
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

/// Le chiamate al server per importare un documento.
class ImportazioniDaDocumento {
  const ImportazioniDaDocumento(this._api);

  final ApiClient _api;

  /// Carica i documenti e mette in coda la trascrizione.
  ///
  /// ══ 🚨 NESSUNO DEI TRE BOOLEANI HA UN VALORE DI PARTENZA ═══════════════
  ///
  /// [dichiarazione] — che il documento l'ha redatto un professionista
  /// abilitato — e [consensoDocumento] — che questi byte possono andare all'AI —
  /// sono **dichiarazioni di chi importa**, e un parametro facoltativo è il
  /// primo posto dove una dichiarazione si perde: basta un chiamante nuovo che
  /// non lo passa, e il consenso sparisce senza che nessun test diventi rosso.
  ///
  /// ⚠️ Il server li pretende `accepted`, non `boolean`: devono arrivare
  /// **veri**, non presenti.
  Future<ImportazioneDaDocumento> carica({
    required List<DocumentoScelto> documenti,
    required bool dichiarazione,
    required bool consensoDocumento,
    required GenereImportato genere,
  }) async {
    /*
     * ⚠️ **L'ordine è quello in cui la persona li ha scelti**, e va conservato
     * fino in fondo: per delle pagine fotografate è l'informazione principale —
     * la seconda letta per prima dà una scheda che comincia da metà.
     */
    final risposta = await _api.upload<Map<String, dynamic>>(
      '/importazioni',
      FormData.fromMap({
        'file': [
          for (final d in documenti)
            MultipartFile.fromBytes(d.byte, filename: d.nome),
        ],
        'dichiarazione': dichiarazione ? '1' : '0',
        'consenso_documento': consensoDocumento ? '1' : '0',
        'genere': genere.valore,
      }),
    );

    return ImportazioneDaDocumento.fromJson(risposta);
  }

  Future<ImportazioneDaDocumento> stato(int id) async {
    final risposta = await _api.get<Map<String, dynamic>>('/importazioni/$id');

    return ImportazioneDaDocumento.fromJson(risposta);
  }

  /*
  | ══ ⛔ `pdf(id)` NON ESISTE PIU' — K1-bis, 03/09/2026 ════════════════════
  |
  | Serviva a farsi riconsegnare dal server il documento che l'app aveva appena
  | caricato. 🚨 Era un giro inutile che costava una copia di un documento
  | sanitario sul nostro disco per sette giorni: **il documento ce l'ha già il
  | telefono**, che è chi l'ha scelto — vedi `DocumentoScelto`.
  |
  | ⚠️ E da K quel file sul server non c'è comunque più: se ne va appena il job
  | ha finito, riuscito o fallito.
  */

  /// Chiude l'importazione: la bozza se ne va dal server.
  ///
  /// 🚨 **Si chiama sia dopo aver confermato sia dopo aver scartato.** La scheda
  /// confermata non resta di là: se la tenessimo avremmo un programma di
  /// allenamento — o peggio una dieta, che è art. 9 — legato a una persona sui
  /// nostri sistemi, cioè l'opposto esatto di D9-bis.
  Future<void> chiudi(int id) => _api.delete('/importazioni/$id');
}

final importazioniProvider = Provider<ImportazioniDaDocumento>(
  (ref) => ImportazioniDaDocumento(ref.watch(apiClientProvider)),
);
