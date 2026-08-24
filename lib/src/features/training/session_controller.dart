import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/storage/archivio_salute.dart';
import '../health/health_controller.dart';
import 'data/calorie_allenamento.dart';
import 'data/catalogo_esercizi.dart';
import 'data/gruppo_muscolare.dart';
import 'data/session_models.dart';

/// Gli allenamenti, **dall'archivio locale** — FASE 11.4, 21/08/2026.
///
/// ══ 🚨 QUESTO FILE PARLAVA COL SERVER, E ADESSO NO ════════════════════════
///
/// 📌 Il committente: *«Nessun allenamento deve risiedere sul server, devono
/// stare tutti nell'app»*. È la decisione già scritta il 16/08 in
/// `plan_tutto_sul_telefono.md` §2.1.
///
/// ⚠️ Fino a `v8.4.1` c'erano **due case per la stessa cosa**: gli allenamenti
/// dell'orologio in locale, quelli del player su `/workout-sessions`. 🚨
/// `storicoUnificatoProvider` esisteva solo per ricucire i due mondi — ed è il
/// motivo per cui la scheda «Allenamento» si è contraddetta da sola (O.D.8).
///
/// ── 💡 Cosa continua a passare dal server, e perché ──────────────────────
///
/// **Il catalogo degli esercizi.** `POST /exercises` resta, ed è l'unica
/// chiamata rimasta qui: quando si aggiunge un esercizio al volo, il server lo
/// riconcilia con la libreria e lo crea se serve.
///
/// 🚨 Non è un residuo da togliere: *«il vocabolario dev'essere comune, o lo
/// storico di due iscritti non è confrontabile»* (C2.3/D3). ⚠️ E porta indietro
/// il **MET**, che serve al calcolo delle calorie.
///
/// 💡 Il guadagno c'è lo stesso: prima serviva la rete **a ogni serie**, adesso
/// solo per un esercizio **nuovo**. In una palestra interrata è la differenza
/// fra un player che funziona e uno che no.
final sessionsProvider = FutureProvider.autoDispose<List<WorkoutSession>>((
  ref,
) async {
  /*
   * 🚨 Si ridisegna quando l'archivio cambia: drift non notifica da solo chi
   * legge con `Future`, e senza questo chi chiude una seduta resterebbe a
   * guardare la lista di prima.
   *
   * 💡 **Si riusa quello di `health_controller`** invece di farne un secondo:
   * lo alza già la sincronizzazione dall'orologio, e dopo la FASE 11 le due
   * cose finiscono nello stesso storico. Due contatori per lo stesso fatto
   * vorrebbero dire due elenchi che si aggiornano in momenti diversi.
   */
  ref.watch(revisioneAllenamentiProvider);

  final archivio = ref.watch(archivioSaluteProvider);
  final kg = await _pesoDiRiferimento(archivio);

  final sedute = await archivio.sedute();
  final serie = await archivio.serieDiPiuSedute(
    sedute.map((s) => s.id).toList(),
  );

  return sedute
      .map(
        (s) => WorkoutSession.dallArchivio(s, serie[s.id] ?? const [], kg: kg),
      )
      .toList();
});

/// Una seduta singola: il player la ricarica dopo ogni chiusura.
final sessionProvider = FutureProvider.autoDispose.family<WorkoutSession, int>((
  ref,
  id,
) async {
  final sessioni = await ref.watch(sessionsProvider.future);

  return sessioni.firstWhere(
    (s) => s.id == id,
    /*
     * ⛔ Non si inventa una seduta vuota: `orElse` con un oggetto finto
     * mostrerebbe una schermata plausibile per una seduta cancellata, invece
     * dell'errore che dice cos'è successo.
     */
    orElse: () => throw StateError('Seduta $id non trovata nell\'archivio'),
  );
});

/// La seduta ancora aperta, se c'è.
///
/// ⚠️ Serve a riprendere un allenamento interrotto: senza, chi chiude l'app a
/// metà seduta si ritrova a doverne aprire una nuova, e lo storico si riempie
/// di sessioni monche.
final openSessionProvider = FutureProvider.autoDispose<WorkoutSession?>((
  ref,
) async {
  final sessioni = await ref.watch(sessionsProvider.future);

  for (final s in sessioni) {
    if (s.isOpen) return s;
  }

  return null;
});

/// Il peso su cui si calcolano le calorie.
///
/// ⚠️ **L'ultimo peso registrato**, non quello del giorno della seduta: un
/// ricalcolo di tutto lo storico con il peso di allora richiederebbe una lettura
/// per riga, e la differenza sul MET × kg × ore è di poche decine di kcal.
/// 💡 È la stessa approssimazione che faceva il server (`bodyweight()`).
///
/// ⛔ Senza nessuna pesata vince `CalorieAllenamento.pesoDiRipiego` — 75 kg,
/// prudente di proposito.
Future<double> _pesoDiRiferimento(ArchivioSalute archivio) async {
  final misure = await archivio.storicoMisure(ultimiGiorni: 365);

  for (final m in misure) {
    final kg = m.pesoKg;
    if (kg != null && kg > 0) return kg;
  }

  return CalorieAllenamento.pesoDiRipiego;
}

class SessionActions {
  SessionActions(this._ref);

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  /// Nome → (id, MET), per non richiedere lo stesso esercizio a ogni serie.
  final _noti = <String, (int, double?)>{};

  ArchivioSalute get _archivio => _ref.read(archivioSaluteProvider);

  void _rileggi() => _ref.read(revisioneAllenamentiProvider.notifier).state++;

  /// Apre una seduta, con o senza scheda.
  Future<WorkoutSession> start({int? planId, String? planName}) async {
    final id = await _archivio.apriSeduta(
      schedaServerId: planId,
      nomeScheda: planName,
    );

    _rileggi();
    _ref.invalidate(sessionsProvider);

    return (await _ref.read(
      sessionsProvider.future,
    )).firstWhere((s) => s.id == id);
  }

  /// Registra una serie.
  ///
  /// 🚨 **È un upsert** sulla terna (seduta, esercizio, numero): rimandare la
  /// stessa serie **non la duplica**. Era la proprietà che rendeva il player
  /// utilizzabile in una palestra interrata quando la scrittura passava dalla
  /// rete; adesso la scrittura è locale e la proprietà resta comunque, perché
  /// correggere un numero sbagliato **è** quello che si vuole.
  ///
  /// ⚠️ `exerciseName` senza `exerciseId` è l'esercizio aggiunto al volo:
  /// **quello sì che passa dal server**, perché il vocabolario dev'essere
  /// comune. 💡 E torna indietro con il suo MET.
  Future<int> logSet({
    required int sessionId,
    required int setNumber,
    int? exerciseId,
    String? exerciseName,

    /// I muscoli, per l'esercizio che il catalogo non conosce — 3b-A.3.5.
    ///
    /// ⛔ Da A.3.5 il server **rifiuta** di creare un esercizio senza: senza
    /// questo, la prima serie di un movimento inventato prenderebbe un 422.
    MuscoliScelti? muscoli,

    int? reps,
    double? weight,
    int? restSec,
  }) async {
    var id = exerciseId;
    double? met;
    var nome = exerciseName ?? 'Esercizio';

    /*
     * 💡 **Una chiamata per esercizio, non per serie.** Il player non conosce
     * gli id: manda il nome, e il server risponde con id e MET. Ricordandoli
     * qui, la seconda serie di panca — e la terza, e la quarta — si scrivono
     * **senza rete**.
     *
     * ⚠️ La memoria vive quanto la sessione dell'app, ed è voluto: il catalogo
     * può cambiare, e un MET ricordato per settimane è un MET vecchio.
     */
    if (exerciseName != null) {
      final noto = _noti[exerciseName];

      if (noto != null) {
        id = noto.$1;
        met = noto.$2;
      } else {
        /*
         * ══ 🚨 PRIMA IL CATALOGO CHE ABBIAMO GIÀ — 3b-B.16.10, 24/08/2026 ══
         *
         * 📌 *«tutto deve stare sul telefono … perché potrei non avere rete
         * quando mi alleno»*.
         *
         * ⛔ Prima si andava **dritti al server**, e senza rete la serie non si
         * salvava affatto: il `throw` qui sotto scattava alla **prima** serie di
         * ogni esercizio, perché il player gli id non ce li ha. In palestra,
         * dove il campo spesso non c'è, questo vuol dire un'app che rifiuta di
         * registrare l'allenamento che stai facendo.
         *
         * 💡 Il catalogo sta già sul telefono (`catalogoEserciziProvider` tiene
         * una copia locale): per i 147 esercizi che conosciamo l'id si trova
         * **senza toccare la rete**. Il server serve solo per un nome che non
         * abbiamo mai visto.
         */
        /*
         * ⚠️ **`await` e non `valueOrNull`.** Preso da un test: con
         * `valueOrNull` il catalogo si usa solo **se per caso** è già caricato,
         * e durante un allenamento spesso non lo è — nessuna schermata del
         * player lo guarda. Il risultato sarebbe stato «a volte funziona»,
         * cioè il tipo di comportamento peggiore da diagnosticare.
         *
         * 💡 Aspettarlo non può bloccare: `catalogoEserciziProvider` ricade
         * sulla copia locale se la rete non c'è, e su un catalogo vuoto se
         * nemmeno quella c'è. Torna sempre.
         */
        final dalTelefono = (await _ref.read(
          catalogoEserciziProvider.future,
        )).perNome(exerciseName);

        if (dalTelefono != null) {
          id = dalTelefono.id;
          met = dalTelefono.met;
          nome = dalTelefono.nome;
        } else {
          try {
            final creato = await _catalogo(exerciseName, muscoli);

            id = (creato['id'] as num?)?.toInt() ?? exerciseId;
            met = (creato['met'] as num?)?.toDouble();
            nome = creato['name']?.toString() ?? exerciseName;
          } on Object catch (e) {
            debugPrint('serie: il catalogo non risponde — $e');
          }
        }

        if (id != null) _noti[exerciseName] = (id, met);
      }
    }

    /*
     * ══ ⛔ UNA SERIE FATTA NON SI PERDE MAI — 3b-B.16.10 ═══════════════════
     *
     * 🚨 Qui c'era un `throw`: senza id la serie **non si salvava**. ⚠️ Era la
     * cosa peggiore che potesse fare — chi ha appena spinto un bilanciere non
     * la rifà perché l'app non aveva campo.
     *
     * 💡 Adesso si salva con un id **provvisorio e negativo**, ricavato dal
     * nome. ⚠️ Negativo di proposito: gli id veri sono positivi, quindi un
     * provvisorio si riconosce a colpo d'occhio e non può collidere.
     *
     * 💡 E lo storico funziona lo stesso: `intensitaDeiMuscoli` cerca prima per
     * id e **poi per nome**, e il nome ce l'ha. Le calorie usano il MET, che
     * senza catalogo non c'è — e lì la stima ricade sul valore di serie.
     *
     * ⏳ **Debito dichiarato**: la riconciliazione (dare l'id vero a una serie
     * provvisoria quando la rete torna) non c'è ancora. Sta nel piano come
     * B.16.13, e finché non c'è quella serie resta con l'id negativo.
     */
    id ??= -exerciseName.hashCode.abs();

    await _archivio.registraSerie(
      SerieDelleSeduteCompanion.insert(
        sedutaId: sessionId,
        esercizioId: id,
        nomeEsercizio: nome,
        met: Value(met),
        numero: setNumber,
        ripetizioni: Value(reps),
        pesoKg: Value(weight),
        riposoSec: Value(restSec),
        fattaIl: Value(DateTime.now()),
      ),
    );

    _rileggi();

    return id;
  }

  /// Chiude la seduta e calcola le calorie.
  ///
  /// 🚨 **Il calcolo gira qui, non sul server**: la formula è stata trasportata
  /// in `CalorieAllenamento` (FASE 11.2) con gli stessi numeri.
  Future<void> finish(int sessionId) async {
    final seduta = (await _archivio.sedute()).firstWhere(
      (s) => s.id == sessionId,
    );

    final serie = await _archivio.serieDi(sessionId);
    final fine = DateTime.now();
    final kg = await _pesoDiRiferimento(_archivio);

    await _archivio.chiudiSeduta(
      sessionId,
      quando: fine,
      /*
       * ⚠️ **Non si sovrascrive una correzione a mano.** `kcalAMano` è la
       * coppia di `kcal`: senza questo controllo, chiudere una seduta su cui
       * qualcuno aveva scritto 800 rimetterebbe la stima — e quel numero
       * sparirebbe senza che nessuno lo abbia chiesto.
       */
      kcal: seduta.kcalAMano
          ? null
          : CalorieAllenamento.formula(
              durata: fine.difference(seduta.iniziataIl),
              kg: kg,
              metMedio: CalorieAllenamento.metMedio(serie.map((r) => r.met)),
            ),
    );

    _rileggi();
    _ref.invalidate(sessionsProvider);
  }

  /// Corregge a mano le calorie. `null` **rimette la stima**, non azzera.
  Future<void> setKcal(int sessionId, int? kcal) async {
    if (kcal == null) {
      /*
       * 💡 «Disfare» vuol dire togliere sia il numero sia il fatto che fosse a
       * mano: da lì in poi `WorkoutSession.dallArchivio` ricalcola con la
       * formula. ⚠️ Lasciare `kcalAMano` a `true` con `kcal` nullo darebbe una
       * seduta che non ha né il numero scritto né la stima.
       */
      await _archivio.chiudiSeduta(
        sessionId,
        quando: (await _archivio.sedute())
            .firstWhere((s) => s.id == sessionId)
            .finitaIl,
        kcalAMano: false,
      );
    } else {
      await _archivio.correggiKcalSeduta(sessionId, kcal);
    }

    _rileggi();
    _ref.invalidate(sessionsProvider);
  }

  Future<void> delete(int sessionId) async {
    await _archivio.cancellaSeduta(sessionId);

    _rileggi();
    _ref.invalidate(sessionsProvider);
  }

  /// L'esercizio aggiunto al volo, riconciliato col catalogo del server.
  ///
  /// 🚨 `200` se esisteva già, `201` solo se è nato adesso — il server
  /// riconosce i nomi. 💡 Ed è il motivo per cui questa chiamata non si può
  /// togliere: due iscritti che scrivono «Panca piana» devono finire
  /// sullo **stesso** esercizio, o lo storico non è confrontabile.
  Future<Map<String, dynamic>> _catalogo(String nome, MuscoliScelti? muscoli) =>
      _api.post<Map<String, dynamic>>(
        '/exercises',
        body: {
          'name': nome,

          // 🚨 Solo se qualcuno ha risposto: mandare un elenco vuoto senza che
          // nessuno l'abbia detto scriverebbe in libreria «questo esercizio
          // isola», che è una dichiarazione diversa da «non lo so». La regola
          // sta in `muscoliInJson`, in un posto solo.
          ...muscoliInJson(muscoli),
        },
      );
}

final sessionActionsProvider = Provider<SessionActions>(SessionActions.new);
