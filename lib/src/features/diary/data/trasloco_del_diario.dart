/// Il diario alimentare viene a casa — Parte I, I3.
///
/// ══ 📌 PERCHÉ ═════════════════════════════════════════════════════════════
///
/// 📌 Regola R3: *«tutto ciò che è anche lontanamente sensibile resta sul
/// telefono»*. 🚨 Cosa mangia una persona è dato dell'art. 9, ed era l'ultima
/// tabella grossa di dati personali rimasta sul server.
///
/// ══ ⛔ QUANTO È SEMPLICE, E PERCHÉ ════════════════════════════════════════
///
/// 📌 Il committente, il 02/09/2026: *«Non ci sono utenti, sono solo io,
/// sticazzi de ste cose, meglio farle adesso che dopo»*.
///
/// 💡 Il piano prevedeva una cerimonia — conferma al server, dati conservati per
/// chi non aggiorna, una decisione «con i numeri veri davanti». ⛔ Quei numeri
/// sono uno. Costruire la cerimonia adesso vorrebbe dire scrivere codice per un
/// problema che non c'è, e mantenerlo finché esiste il progetto.
///
/// 🚨 **Il conteggio resta**, ed è l'unica cosa che non si taglia: è la
/// differenza fra *«i dati sono stati spostati»* e *«i dati sono stati persi»*,
/// e costa una riga.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/storage/archivio_salute.dart';
import '../../../core/storage/local_cache.dart';
import '../../health/health_controller.dart';

/// Com'è andato il trasloco.
enum EsitoTrasloco {
  /// 🎉 Fatto adesso.
  fatto,

  /// 💡 Era già stato fatto: non si rifà, e non è un errore.
  giaFatto,

  /// ⛔ Il server ha risposto, ma i conteggi non tornano: **non si tocca
  /// niente**. Vedi [Trasloco.porta].
  nonTorna,

  /// La rete, il server: si riproverà al prossimo avvio.
  nonRiuscito,
}

/// Se il trasloco è già stato fatto su questo telefono.
///
/// ⚠️ **Nelle preferenze e non in una tabella**: è uno stato di questa
/// installazione, non un dato della persona. 💡 E finisce nel backup da solo
/// (`PreferenzeNelBackup` le enumera tutte) — il che è giusto: chi ripristina su
/// un telefono nuovo si porta dietro il diario, e non deve rifare il viaggio.
const chiaveTraslocoFatto = 'diario.trasloco_fatto';

/// La versione del pacchetto che questo telefono ha già preso.
///
/// ══ 🚨 PERCHE' UN NUMERO E NON UN «SI'» ═══════════════════════════════════
///
/// Perché il pacchetto **cresce**. La prima versione non portava il contatore
/// d'uso dei preferiti, e chi aveva già traslocato se li sarebbe tenuti a zero
/// per sempre — con l'elenco in ordine cronologico invece che per uso, e
/// nessun modo di accorgersene guardando.
///
/// 💡 Con un numero, aggiungere un campo al pacchetto significa alzarlo di uno:
/// il trasloco riparte da solo, le voci del diario non si duplicano
/// (`insertOrIgnore`) e i preferiti si rifanno.
///
/// ⚠️ **Si alza solo quando il pacchetto guadagna qualcosa**, non a ogni
/// modifica: un numero che cambia per abitudine fa riscaricare tutto a ogni
/// aggiornamento dell'app.
const versioneDelTrasloco = 2;

class Trasloco {
  const Trasloco(this._api, this._archivio, this._cache);

  final ApiClient _api;
  final ArchivioSalute _archivio;
  final LocalCache _cache;

  /// Porta il diario a casa.
  ///
  /// ══ 🚨 L'ORDINE, CHE È TUTTO ══════════════════════════════════════════
  ///
  /// 1. si scarica **tutto**;
  /// 2. si scrive nell'archivio;
  /// 3. 🚨 **si ricontano le righe scritte** e si confrontano con quelle che il
  ///    server dice di avere;
  /// 4. solo se tornano, si segna che è fatto.
  ///
  /// ⛔ **Senza il passo 3 non è un trasloco, è una speranza.** Una risposta
  /// troncata, un campo che non si converte, una riga che l'indice unico
  /// scarta: sono tutte cose che non danno errore e lasciano metà diario. E
  /// mezzo diario è **peggio** di nessun diario, perché i totali sembrano veri.
  ///
  /// 💡 Se non tornano si riprova al prossimo avvio: le righe già scritte non
  /// si duplicano — ci pensa `insertOrIgnore` su `idSulServer`.
  Future<EsitoTrasloco> porta() async {
    final fatta = int.tryParse(_cache.getString(chiaveTraslocoFatto) ?? '') ?? 0;

    if (fatta >= versioneDelTrasloco) {
      return EsitoTrasloco.giaFatto;
    }

    try {
      final dati = await _api.get<Map<String, dynamic>>('/trasloco/diario');

      final voci = (dati['voci'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_voce)
          .toList(growable: false);

      final preferiti = (dati['preferiti'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_preferito)
          .toList(growable: false);

      await _archivio.importaVociDelDiario(voci);
      await _archivio.importaPreferiti(preferiti);

      /*
       * 🚨 **Si riconta l'archivio, non la lista appena mandata.**
       *
       * ⛔ Contare `voci.length` risponderebbe «quante ne ho spedite», che è la
       * domanda sbagliata: quella giusta è **quante ne sono arrivate a
       * destinazione**. Fra le due c'è tutto ciò che può andare storto senza
       * dare errore.
       */
      final scritte = await _archivio.quanteVociDelDiario();
      final attese = (dati['quante_voci'] as num?)?.toInt() ?? voci.length;

      if (scritte < attese) {
        debugPrint('trasloco: $scritte righe su $attese — non si conferma');

        return EsitoTrasloco.nonTorna;
      }

      await _cache.setString(chiaveTraslocoFatto, '$versioneDelTrasloco');

      return EsitoTrasloco.fatto;
    } on Object catch (e) {
      debugPrint('trasloco: non riuscito — $e');

      return EsitoTrasloco.nonRiuscito;
    }
  }

  /// ⚠️ `DateTime.parse` e non `tryParse` su `eaten_at`: una voce senza data non
  /// è una voce con una data ignota, è una riga che non si può mettere in
  /// nessun giorno. 💡 Meglio far fallire il trasloco — che si riprova — che
  /// scriverla sotto una data inventata.
  VociDiarioCompanion _voce(Map<String, dynamic> v) => VociDiarioCompanion.insert(
    mangiatoIl: DateTime.parse(v['eaten_at'].toString()).toLocal(),
    pasto: v['meal']?.toString() ?? 'lunch',
    descrizione: v['description']?.toString() ?? '—',
    idSulServer: Value((v['id'] as num?)?.toInt()),
    grammi: Value(_numero(v['grams'])),
    quantita: Value(_numero(v['qty'])),
    unita: Value(v['unit']?.toString()),
    kcal: Value(_numero(v['kcal'])),
    proteine: Value(_numero(v['protein'])),
    carboidrati: Value(_numero(v['carbs'])),
    grassi: Value(_numero(v['fat'])),
    kcal100: Value(_numero(v['kcal_100'])),
    proteine100: Value(_numero(v['protein_100'])),
    carboidrati100: Value(_numero(v['carbs_100'])),
    grassi100: Value(_numero(v['fat_100'])),
    fonte: Value(v['source']?.toString() ?? 'manual'),
    aiGrezzo: Value(v['ai_raw']?.toString()),
    pianoId: Value((v['nutrition_plan_id'] as num?)?.toInt()),
    alimentoId: Value((v['food_id'] as num?)?.toInt()),

    /*
     * 💡 `created_at` diventa `scrittaIl`: è il campo che distingue una cena
     * **programmata** alle 10 del mattino da una mangiata alle 21, e senza di
     * lui il consiglio del giorno tornerebbe a sbagliare come prima di 3b-AC.
     *
     * ⚠️ Il ripiego su `eaten_at` serve alle righe più vecchie del campo.
     */
    scrittaIl: Value(
      DateTime.tryParse(v['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.parse(v['eaten_at'].toString()).toLocal(),
    ),
  );

  PreferitiCiboCompanion _preferito(Map<String, dynamic> p) =>
      PreferitiCiboCompanion.insert(
        descrizione: p['description']?.toString() ?? '—',
        idSulServer: Value((p['id'] as num?)?.toInt()),
        ePasto: Value(p['is_meal'] == true),
        voci: Value(p['items']?.toString()),
        grammi: Value(_numero(p['grams'])),
        quantita: Value(_numero(p['qty'])),
        unita: Value(p['unit']?.toString()),
        kcal: Value(_numero(p['kcal'])),
        proteine: Value(_numero(p['protein'])),
        carboidrati: Value(_numero(p['carbs'])),
        grassi: Value(_numero(p['fat'])),
        kcal100: Value(_numero(p['kcal_100'])),
        proteine100: Value(_numero(p['protein_100'])),
        carboidrati100: Value(_numero(p['carbs_100'])),
        grassi100: Value(_numero(p['fat_100'])),
        salvatoIl: Value(
          DateTime.tryParse(p['created_at']?.toString() ?? '') ?? DateTime.now(),
        ),

        // 🚨 Metà dell'ordinamento: senza, i preferiti ci sono tutti e sono
        // nell'ordine sbagliato — e un elenco non si guarda per accorgersene.
        volteUsato: Value((p['times_used'] as num?)?.toInt() ?? 0),
        usatoIl: Value(
          DateTime.tryParse(p['last_used_at']?.toString() ?? '')?.toLocal(),
        ),
      );

  /// ⚠️ Il server manda i decimali come **stringhe** (`decimal` di MySQL via
  /// JSON): `as double?` li butterebbe via in silenzio, e il diario arriverebbe
  /// senza calorie.
  static double? _numero(Object? v) => switch (v) {
    null => null,
    final num n => n.toDouble(),
    _ => double.tryParse(v.toString()),
  };
}

/// Quante voci di diario ci sono **su questo telefono**.
///
/// ══ 🚨 PERCHE' ESISTE: IL TRASLOCO NON SI VEDE ═══════════════════════════
///
/// Il trasloco (I3) succede in silenzio, e in release **non lascia traccia**:
/// `debugPrint` non arriva a logcat, e l'access log del server vuole permessi
/// che su una macchina condivisa non si prendono per una verifica.
///
/// ⛔ Il momento in cui si scoprirebbe da solo è **I2**, quando il diario
/// comincia a leggersi dal telefono — cioè il momento peggiore: un trasloco
/// fallito apparirebbe come un diario vuoto, e sembrerebbe che a perdere i dati
/// sia stato I2.
///
/// 💡 Quindi il numero si mostra **prima**, dove si dice già cosa c'è su questo
/// telefono: nella schermata del backup.
final vociSulTelefonoProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(archivioSaluteProvider).quanteVociDelDiario(),
);

final traslocoProvider = Provider<Trasloco>(
  (ref) => Trasloco(
    ref.watch(apiClientProvider),
    ref.watch(archivioSaluteProvider),
    ref.watch(localCacheProvider),
  ),
);
