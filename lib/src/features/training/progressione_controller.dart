/// La progressione degli esercizi: storia, analisi, e chi può vederle — 3b-I.A.
///
/// ══ 🚨 DUE COSE DIVERSE, E SOLO UNA COSTA ═════════════════════════════════
///
/// | | Da dove viene | Costa | Chi la vede |
/// |---|---|---|---|
/// | **La sparkline** | dal telefono, sempre | niente | solo gli abbonati |
/// | **La riga dell'AI** | dal server, su richiesta | 1 gettone | solo gli abbonati |
///
/// 💡 La sparkline si disegna **senza chiedere niente a nessuno**: i dati sono
/// già sul telefono. ⛔ Chiamare il server per disegnarla sarebbe far pagare una
/// cosa che abbiamo già.
///
/// ══ ⚠️ E L'ANALISI NON SI RIGENERA DA SOLA ════════════════════════════════
///
/// 🚨 Non c'è **nessun** percorso in questo file che chiami il modello senza che
/// qualcuno abbia toccato un pulsante. Un'analisi che si rigenera aprendo la
/// pagina sarebbe un gettone speso ogni volta che si guarda una scheda — e la
/// persona lo scoprirebbe dal saldo, non dall'app.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/errors/api_exception.dart';
import '../../core/providers.dart';
import '../../core/storage/archivio_salute.dart';
import '../auth/auth_controller.dart';
import '../dashboard/gettoni_controller.dart';
import '../health/health_controller.dart';
import 'data/limiti_delle_schede.dart';
import 'data/progressione.dart';

/// Quanto può stare ferma un'analisi prima di poterla rifare.
///
/// 📌 *«facciamoglielo fare una sola volta per scheda»*: qui la regola è più
/// larga — si può rifare, ma non subito.
///
/// ⚠️ **Sette giorni e non uno**: una scheda si fa due o tre volte a settimana,
/// e un'analisi rifatta dopo una sola seduta racconta la stessa cosa con altre
/// parole. 💡 Il limite non protegge noi, protegge il saldo di chi tocca.
const attesaFraDueAnalisi = Duration(days: 7);

/// Se questa persona può vedere progressione e analisi.
///
/// 🚨 **La stessa funzione delle schede** (`senzaLimiti`), non una copia: il
/// giorno in cui la regola dell'abbonamento cambia, deve cambiare in un posto
/// solo. ⛔ La seconda stesura della stessa condizione l'ho già sbagliata due
/// volte — è scritto in `limiti_delle_schede.dart`.
final puoVedereIProgressiProvider = Provider.autoDispose<bool>((ref) {
  final gettoni = ref.watch(gettoniProvider).valueOrNull;

  return senzaLimiti(
    abbonato: ref.watch(authControllerProvider).user?.abbonato,
    illimitata: gettoni?.illimitata,
  );
});

/// La storia degli esercizi di una scheda, dal telefono.
///
/// ⚠️ **Sull'id del server**, non su quello locale: le sedute lo registrano
/// così, e l'id locale cambia da telefono a telefono.
final storiaDellaSchedaProvider = FutureProvider.autoDispose
    .family<Map<int, List<PuntoDiProgressione>>, int>(
      (ref, schedaServerId) =>
          ref.watch(archivioSaluteProvider).storiaDegliEsercizi(schedaServerId),
    );

/// L'analisi già scritta, se c'è.
final analisiDellaSchedaProvider = FutureProvider.autoDispose
    .family<AnalisiInCorso?, int>((ref, schedaServerId) async {
      ref.watch(revisioneDellAnalisiProvider);

      final riga = await ref
          .watch(archivioSaluteProvider)
          .analisiDellaScheda(schedaServerId);

      if (riga == null) return null;

      final storia = await ref.watch(
        storiaDellaSchedaProvider(schedaServerId).future,
      );

      return AnalisiInCorso(
        righe: _daJson(riga.righe),
        fattaIl: riga.fattaIl,

        /*
         * 🚨 **Il confronto si fa QUI, non in un widget.** «È ancora attuale?»
         * è una domanda sui dati, e un widget che la ricalcola per conto suo è
         * un secondo posto dove la regola può divergere — cioè un'app che dice
         * «aggiornata» in una schermata e «superata» in un'altra.
         */
        superata: riga.impronta != improntaDelloStorico(storia),
      );
    });

/// 💡 Il contatore che fa ridisegnare dopo un'analisi nuova: drift non notifica
/// da solo su queste tabelle, e invalidare l'archivio intero ricaricherebbe
/// mezza app.
final revisioneDellAnalisiProvider = StateProvider<int>((ref) => 0);

/// L'analisi come la legge la schermata.
class AnalisiInCorso {
  const AnalisiInCorso({
    required this.righe,
    required this.fattaIl,
    required this.superata,
  });

  final List<ProgressoEsercizio> righe;
  final DateTime fattaIl;

  /// Da quando è stata scritta sono state fatte altre sedute.
  final bool superata;

  /// Quando si potrà rifare, o `null` se si può già.
  DateTime? get rifacibileDal {
    final quando = fattaIl.add(attesaFraDueAnalisi);

    return quando.isAfter(DateTime.now()) ? quando : null;
  }

  ProgressoEsercizio? per(int esercizioId) {
    for (final r in righe) {
      if (r.esercizioId == esercizioId) return r;
    }

    return null;
  }
}

/// Perché l'analisi non si è potuta fare.
enum EsitoAnalisi {
  fatta,

  /// ⛔ Non è abbonato. Porta alla modale.
  serveAbbonamento,

  /// ⚠️ Non ci sono abbastanza sedute: non è un guasto, è che non c'è niente
  /// da raccontare.
  troppoPocoStorico,

  /// 💡 È stata fatta da poco. Il limite è nostro, e va detto senza scusarsi.
  troppoPresto,

  /// Gettoni finiti, o quota del mese esaurita.
  senzaGettoni,

  /// La rete, il server, il modello: una cosa sola perché la persona non può
  /// farci niente di diverso in nessuno dei tre casi.
  nonRiuscita,
}

/// Chiede al server l'analisi della scheda, e la scrive sul telefono.
///
/// ══ ⚠️ L'ORDINE DEI CONTROLLI NON È CASUALE ═══════════════════════════════
///
/// Prima *hai diritto*, poi *c'è qualcosa da dire*, poi *non l'hai appena
/// fatta*. 🚨 Girato, chi non è abbonato si sentirebbe dire «troppo poco
/// storico» — cioè una spiegazione vera che nasconde quella che conta.
///
/// ⚠️ **`WidgetRef` e non `Ref`**: la chiama un pulsante, e in Riverpod i due
/// tipi non sono intercambiabili — `Ref` è quello di dentro un provider. 💡 È
/// la stessa firma di `salvaLaSettimana`, per la stessa ragione.
Future<EsitoAnalisi> chiediLAnalisi(
  WidgetRef ref, {
  required int schedaServerId,
  required Map<int, String> nomiDegliEsercizi,
  bool forza = false,
}) async {
  if (!ref.read(puoVedereIProgressiProvider)) {
    return EsitoAnalisi.serveAbbonamento;
  }

  final storia = await ref.read(
    storiaDellaSchedaProvider(schedaServerId).future,
  );

  if (!valeLaPenaAnalizzare(storia)) return EsitoAnalisi.troppoPocoStorico;

  if (!forza) {
    final gia = await ref.read(
      analisiDellaSchedaProvider(schedaServerId).future,
    );

    if (gia != null && gia.rifacibileDal != null) {
      return EsitoAnalisi.troppoPresto;
    }
  }

  /*
   * ⚠️ **Si mandano solo gli esercizi che hanno una storia.** Mandare anche
   * quelli mai fatti vorrebbe dire pagare del contesto per farsi rispondere
   * «poco storico» — una cosa che sappiamo già senza chiedere a nessuno.
   */
  final corpo = <Map<String, Object?>>[];

  for (final voce in storia.entries) {
    if (voce.value.length < 2) continue;

    corpo.add({
      'id': voce.key,
      'nome': nomiDegliEsercizi[voce.key] ?? 'Esercizio',
      'sedute': [for (final p in voce.value) p.versoIlServer()],
    });
  }

  if (corpo.isEmpty) return EsitoAnalisi.troppoPocoStorico;

  try {
    final risposta = await ref
        .read(apiClientProvider)
        .post<List<dynamic>>(
          '/ai/scheda/progresso',
          body: {'esercizi': corpo},
        );

    final righe = [
      for (final r in risposta)
        ProgressoEsercizio.daJson(Map<String, Object?>.from(r as Map)),
    ];

    await ref
        .read(archivioSaluteProvider)
        .scriviLAnalisi(
          AnalisiDelleSchedeCompanion.insert(
            schedaServerId: Value(schedaServerId),
            righe: jsonEncode([for (final r in righe) r.aJson()]),

            /*
             * 🚨 **L'impronta è quella dello storico INTERO**, non solo degli
             * esercizi mandati. ⚠️ Con l'impronta dei soli mandati, una seduta
             * su un esercizio nuovo non farebbe scattare «superata» — e
             * l'analisi resterebbe a dire che quell'esercizio non c'è.
             */
            impronta: improntaDelloStorico(storia),
            fattaIl: DateTime.now(),
          ),
        );

    ref.read(revisioneDellAnalisiProvider.notifier).state++;

    return EsitoAnalisi.fatta;
  } on Object catch (e) {
    /*
     * 🚨 **`unwrapError` e non un `catch` tipizzato.** Quello che `dio` lancia
     * è una `DioException` che *contiene* la nostra eccezione: `on
     * ForbiddenException` non scatta mai, ed è la trappola già pagata in
     * `dashboard_controller.dart` il 12/08.
     */
    final tradotto = ApiClient.unwrapError(e);

    if (tradotto is ForbiddenException) return EsitoAnalisi.serveAbbonamento;

    if (tradotto is AiQuotaExceededException) return EsitoAnalisi.senzaGettoni;

    return EsitoAnalisi.nonRiuscita;
  }
}

/// @nodoc
List<ProgressoEsercizio> _daJson(String testo) {
  final letto = jsonDecode(testo);

  if (letto is! List) return const [];

  return [
    for (final r in letto)
      if (r is Map) ProgressoEsercizio.daJson(Map<String, Object?>.from(r)),
  ];
}
