/// Dove finisce una bozza importata — Parte K, K2-bis e K3.3.
///
/// ══ 🚨 NON SUL SERVER ═════════════════════════════════════════════════════
///
/// I due compositori sono nati per il **trainer** e salvano su
/// `POST /workout-plans` e `/nutrition-plans`. ⛔ Una scheda importata da un
/// iscritto deve finire nell'archivio locale: salvarla di là vorrebbe dire un
/// piano di allenamento con un nome sopra sui nostri sistemi, cioè l'opposto
/// esatto di D9-bis.
///
/// 💡 È il punto in cui si può sbagliare **in silenzio**: una scheda salvata sul
/// server compare lo stesso nell'elenco, e nessuno se ne accorge finché qualcuno
/// non guarda il database.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/archivio_salute.dart';
import '../../health/health_controller.dart';
import '../../training/data/scheda_allenamento.dart';

/// Il risultato del salvataggio, che a volte è **più di una scheda**.
class BozzaSalvata {
  const BozzaSalvata({required this.quante, required this.divisa});

  final int quante;

  /// Se una scheda multiday è stata divisa in N schede da un giorno.
  final bool divisa;
}

class SalvaLaBozza {
  const SalvaLaBozza(this._archivio);

  final ArchivioSalute _archivio;

  /// Salva una scheda importata **su questo telefono**.
  ///
  /// ══ 🚨 UNA MULTIDAY DIVENTA N SCHEDE, SE CHI IMPORTA NON E' ABBONATO ═════
  ///
  /// 📌 Il committente, il 03/09/2026: *«l'utente non abbonato non può avere
  /// schede multiday, quindi alla fine del controllo, il sistema deve generare x
  /// schede per quanti giorni ci sono in quella originale»*.
  ///
  /// ⚠️ **Chi è abbonato non subisce nessuna divisione**: la scheda resta una,
  /// con i suoi giorni.
  ///
  /// ══ ⛔ E SI SALVANO TUTTE, ANCHE OLTRE IL LIMITE DELLE TRE ═══════════════
  ///
  /// Chi non è abbonato ha tre schede. Una importata da **quattro** giorni ne
  /// genera quattro, e la quarta non si potrà aprire.
  ///
  /// 🚨 **Rifiutare qui sarebbe l'esito peggiore possibile**: l'import costa
  /// **50 gettoni**, e il rifiuto arriverebbe dopo che la persona ha pagato *e*
  /// confrontato quaranta righe. 💡 Le eccedenti risultano bloccate
  /// nell'elenco, con il motivo già scritto sotto — è la regola che esiste da
  /// 3b-D — e 📌 *«il limite conta le schede che hai, non quelle che puoi
  /// usare»*.
  ///
  /// ⚠️ Che diventeranno N si dice **prima** della revisione, non qui: vedi
  /// `AvvisoDeiGiorni`.
  Future<BozzaSalvata> scheda(
    SchedaAllenamento scheda, {
    required bool abbonato,
    required int importazioneId,
  }) async {
    final divide = !abbonato && scheda.giorni.length > 1;

    if (!divide) {
      await _scriviScheda(scheda, importazioneId, indice: 0);

      return const BozzaSalvata(quante: 1, divisa: false);
    }

    for (final (i, giorno) in scheda.giorni.indexed) {
      /*
       * 💡 **Il nome del giorno se ce l'ha**, altrimenti «<nome> — Giorno N».
       *
       * ⛔ Non solo «Giorno 1»: fra tre settimane, in un elenco, non direbbe da
       * dove viene.
       */
      final titolo = (giorno.nome ?? '').trim();

      final singola = SchedaAllenamento(
        nome: titolo.isEmpty ? '${scheda.nome} — Giorno ${i + 1}' : titolo,
        note: scheda.note,
        giorni: [giorno],
      );

      await _scriviScheda(singola, importazioneId, indice: i);
    }

    return BozzaSalvata(quante: scheda.giorni.length, divisa: true);
  }

  /// ⚠️ **`origineIdStabile` porta anche l'indice del giorno.**
  ///
  /// 🚨 Senza, le quattro schede nate dallo stesso import avrebbero la stessa
  /// origine: un salvataggio ripetuto — la persona torna indietro e riconferma —
  /// ne riscriverebbe una sola, e le altre tre resterebbero quelle di prima.
  Future<void> _scriviScheda(
    SchedaAllenamento scheda,
    int importazioneId, {
    required int indice,
  }) => _archivio.aggiungiScheda(
    nome: scheda.nome,
    scheda: jsonEncode(scheda.toJson()),

    /*
     * 💡 **`mia: true`**: chi importa un documento suo diventa proprietario di
     * quella scheda. ⚠️ Non è arrivata da un trainer, e trattarla come ricevuta
     * la renderebbe non modificabile.
     */
    mia: true,
    origine: 'importata',
    origineIdStabile: 'importazione:$importazioneId:$indice',
  );
}

final salvaLaBozzaProvider = Provider<SalvaLaBozza>(
  (ref) => SalvaLaBozza(ref.watch(archivioSaluteProvider)),
);
