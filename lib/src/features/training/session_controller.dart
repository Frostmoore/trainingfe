import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/il_giro_dei_promemoria.dart';
import '../../core/storage/archivio_salute.dart';
import '../acquisti/data/gate_dell_abbonamento.dart';
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

/// 🔒 Il limite del giorno è stato raggiunto — 08/09/2026.
///
/// 💡 **Un tipo e non un messaggio**: chi lo prende deve poter aprire il
/// listino, non stampare una frase. ⛔ Riconoscere un limite dal testo
/// dell'errore è la stessa cosa che il committente ha fatto togliere dal
/// server il 29/08 (*«è una merda se esce solo un errore, si deve capire che è
/// perché non ha pagato»*).
class TroppiAllenamentiOggi implements Exception {
  const TroppiAllenamentiOggi();

  @override
  String toString() =>
      'Senza abbonamento puoi far partire un allenamento al giorno.';
}

class SessionActions {
  SessionActions(this._ref);

  final Ref _ref;

  /// Nome → (id, MET), per non richiedere lo stesso esercizio a ogni serie.
  final _noti = <String, (int, double?)>{};

  ArchivioSalute get _archivio => _ref.read(archivioSaluteProvider);

  void _rileggi() => _ref.read(revisioneAllenamentiProvider.notifier).state++;

  /// Apre una seduta, con o senza scheda.
  ///
  /// ══ 🔒 UN ALLENAMENTO AL GIORNO SENZA ABBONAMENTO — 08/09/2026 ═════════
  ///
  /// 📌 *«un utente non abbonato può far partire dall'app un solo allenamento
  /// al giorno»*.
  ///
  /// 🚨 **Il controllo sta qui e non nel pulsante.** `plans_screen` ha già un
  /// controllo al momento di partire per le schede bloccate, e la tentazione
  /// era di aggiungerne un secondo accanto. ⛔ Ma i punti da cui una seduta può
  /// nascere sono destinati a diventare più d'uno — dalla scheda, da «Oggi»,
  /// dalla settimana — e una regola scritta su ogni pulsante è una regola che
  /// prima o poi manca su un pulsante.
  ///
  /// ⚠️ **Lancia invece di tornare `null`**: chi chiama deve *spiegare*, e un
  /// `null` costringerebbe a indovinare se è un limite o un guasto. 💡 Il tipo
  /// [TroppiAllenamentiOggi] dice quale delle due cose è, come fa il server con
  /// i suoi codici invece che con le frasi.
  Future<WorkoutSession> start({int? planId, String? planName}) async {
    if (!_ref.read(abbonatoProvider)) {
      final quante = await _archivio.quanteSeduteIl(DateTime.now());

      if (quante >= allenamentiAlGiornoSenzaAbbonamento) {
        throw const TroppiAllenamentiOggi();
      }
    }

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
          /*
           * ══ 🆕 🚨 UN NOME NUOVO È UN ESERCIZIO SUO, SUL TELEFONO — D6 ══════
           *
           * ⛔ Qui si chiamava `POST /exercises`, e senza rete si salvava un id
           * provvisorio che poi il server rifiutava di rendere vero (mancavano
           * i muscoli: giro del 18/09). 📌 Il committente, 19/09: *«non vedo
           * per quale motivo dovrebbe essere salvato sul server. Resta suo, e
           * lo vede solo lui. I muscoli devono essere obbligatori»*.
           *
           * 💡 Quindi niente rete, mai: l'esercizio nasce nell'archivio con i
           * muscoli scelti nel player (`_muscoliSeServono` non lascia passare
           * un esercizio nuovo senza), e ha subito il suo id definitivo.
           */
          id = await _archivio.salvaEsercizioMio(
            nome: exerciseName.trim(),
            // ⚠️ `null` solo se qualcuno chiama `logSet` senza passare dal
            // player: un muscolo inventato sarebbe peggio di «da indicare».
            primario: muscoli?.primario?.valore,
            secondari: [
              for (final m in muscoli?.secondari ?? const <GruppoMuscolare>[])
                m.valore,
            ],
          );
          nome = exerciseName.trim();

          // 💡 Da adesso il catalogo lo conosce: la prossima ricerca lo trova.
          _ref.invalidate(catalogoEserciziProvider);
        }

        _noti[exerciseName] = (id, met);
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
     * 🆕 **Da D6 (19/09) ci si arriva solo senza nome**: un nome nuovo diventa
     * un esercizio suo sul telefono, qui sopra, con un id definitivo. ⛔ La
     * «riconciliazione» di B.16.13 non esiste più: il server rifiutava gli
     * esercizi senza muscoli, e comunque non dovevano andarci.
     */
    id ??= -(exerciseName ?? nome).hashCode.abs();

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

    /*
     * 🆕 ⏰ **I promemoria si rifanno** — voce 62, 27/09/2026.
     *
     * ⛔ Senza questa riga, chi finisce di allenarsi alle 17 si sente chiedere
     * «ci alleniamo?» alle 18: il promemoria era già programmato, e nessuno lo
     * cancella. 🚨 Un promemoria che arriva per una cosa appena fatta è il
     * genere di errore per cui si spengono tutte le notifiche.
     *
     * ⚠️ `unawaited` e mai un `await`: ⛔ far fallire la chiusura di una seduta
     * perché non si è riusciti a riprogrammare un avviso vorrebbe dire perdere
     * l'allenamento. `rifai()` non lancia comunque, questo è il secondo strato.
     */
    unawaited(_ref.read(giroDeiPromemoriaProvider).rifai());
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
}

final sessionActionsProvider = Provider<SessionActions>(SessionActions.new);
