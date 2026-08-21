import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/local_cache.dart';

/// L'attesa di una stima, dal lato dell'app — FASE 9.6 e 9.7.
///
/// ══ 🚨 PERCHÉ LA STIMA NON ARRIVA PIÙ NELLA RISPOSTA ══════════════════════
///
/// Perché `POST /ai/food/text` teneva occupato un processo PHP del server per
/// **2–8 secondi**, e i processi sono **sei**. ⚠️ Il cibo si scrive a pranzo e a
/// cena, cioè per definizione tutti insieme: a sette persone contemporanee non
/// si fermava l'AI, **si fermava il sito**.
///
/// 💡 Adesso il server risponde in ~50 ms con un numero di pratica, e questa
/// classe aspetta al posto suo. **Non è più veloce** — è che l'attesa sta qui,
/// dove non blocca nessun altro.
///
/// ── 🚨 L'id si scrive PRIMA di cominciare ad aspettare ────────────────────
///
/// Se l'app viene chiusa mentre pensa, il lavoro sul server **continua**: è il
/// senso della coda. ⚠️ Al rientro l'app deve **ritrovarlo**, non ricominciare —
/// ricominciare vorrebbe dire una seconda chiamata al modello per lo stesso
/// piatto, pagata due volte e con l'utente che non se ne accorge.
///
/// 💡 E c'è una seconda rete di sicurezza che non dipende dal telefono:
/// `GET /ai/food/stime/in-corso`. Chi ha svuotato i dati dell'app, o ha cambiato
/// telefono, quell'id non ce l'ha.
class StimeInCoda {
  /// 💡 Posizionali e non con nome: i parametri con nome non possono
  /// riferirsi a campi privati (`required this._api` non compila), e la
  /// ripetizione `api: api` faceva scattare `prefer_initializing_formals`.
  const StimeInCoda(this._api, this._cache);

  final ApiClient _api;
  final LocalCache _cache;

  /// 🚨 Fuori dal backup: è un numero di pratica che vive minuti, non un dato.
  /// Ritrovarselo dopo un ripristino vorrebbe dire aspettare una stima che sul
  /// server non esiste più.
  static const chiaveInSospeso = 'stima.in_sospeso';

  /// Ogni quanto si chiede «è pronta?».
  ///
  /// 💡 Un secondo e mezzo è il compromesso fra «sembra istantanea» e «non
  /// martella»: la stima tipica dura ~2,5 s, quindi in genere bastano due
  /// domande. ⚠️ Il server tiene queste richieste **fuori dal semaforo** proprio
  /// perché sono tante e non costano niente.
  static const ogniQuanto = Duration(milliseconds: 1500);

  /// Dopo quanto si smette di aspettare.
  ///
  /// ⚠️ **Non è il tempo massimo del lavoro**: il lavoro va avanti lo stesso sul
  /// server. È il tempo dopo il quale ha più senso dire *«puoi chiudere, lo
  /// ritrovi qui»* che continuare a far fissare una rotellina.
  static const rinuncia = Duration(seconds: 90);

  /// Accoda una stima da testo e ne restituisce l'id.
  Future<int> accodaTesto({
    required String testo,
    required String pasto,
    required DateTime quando,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/ai/food/text',
      body: {
        'text': testo,
        'meal': pasto,
        'eaten_at': quando.toIso8601String(),
      },
    );

    return _ricorda(data);
  }

  /// Accoda una stima da foto e ne restituisce l'id.
  Future<int> accodaFoto(FormData form) async {
    final data = await _api.upload<Map<String, dynamic>>(
      '/ai/food/photo',
      form,
    );

    return _ricorda(data);
  }

  /// Aspetta che la stima sia pronta.
  ///
  /// [avanzamento] riceve **da quanto si sta aspettando**: serve alla schermata
  /// per cambiare quello che dice invece di limitarsi a girare. 🚨 Una rotellina
  /// che gira senza dire niente è indistinguibile da un'app bloccata — ed è il
  /// momento in cui una persona chiude e riprova, cioè **accoda un secondo
  /// lavoro**.
  ///
  /// Torna la stima **con il pasto e l'origine**: chi riprende un lavoro
  /// lasciato a metà (FASE 9.7) deve poter riaprire il foglio di conferma nel
  /// pasto giusto, e non ha nessun altro posto da cui saperlo.
  ///
  /// Lancia [StimaFallita] se il server dice che non è riuscita.
  ///
  /// 💡 [passo] esiste per i test: un'attesa vera di un secondo e mezzo
  /// renderebbe ogni prova del ciclo lunga quanto il ciclo. ⚠️ In produzione
  /// non lo passa nessuno.
  Future<StimaPronta> aspetta(
    int id, {
    void Function(Duration)? avanzamento,
    Duration? passo,
  }) async {
    final inizio = DateTime.now();

    while (true) {
      final passato = DateTime.now().difference(inizio);

      if (passato > rinuncia) {
        throw const StimaTroppoLenta();
      }

      avanzamento?.call(passato);

      final data = await _api.get<Map<String, dynamic>>('/ai/food/stime/$id');
      final stato = data['stato']?.toString();

      if (stato == 'pronta') {
        await dimentica();

        final risultato = data['risultato'];

        if (risultato is Map<String, dynamic>) {
          return StimaPronta(
            risultato: risultato,
            pasto: data['pasto']?.toString(),
            daFoto: data['origine']?.toString() == 'foto',
          );
        }

        // ⚠️ «Pronta senza risultato» non dovrebbe succedere: se succede è un
        // difetto nostro, e va detto come tale invece di restituire una stima
        // vuota che l'utente leggerebbe come «non ho capito il piatto».
        throw const StimaFallita('risultato_mancante');
      }

      if (stato == 'fallita') {
        await dimentica();

        throw StimaFallita(data['errore']?.toString() ?? 'sconosciuto');
      }

      await Future<void>.delayed(passo ?? ogniQuanto);
    }
  }

  /// C'è qualcosa in sospeso? — FASE 9.7.
  ///
  /// 💡 Guarda **prima** sul telefono e **poi** sul server: l'id locale evita
  /// una richiesta a chi non ha niente in corso, che è il caso normale.
  Future<int?> inSospeso() async {
    final locale = int.tryParse(_cache.getString(chiaveInSospeso) ?? '');

    if (locale != null) return locale;

    try {
      final data = await _api.get<Map<String, dynamic>?>(
        '/ai/food/stime/in-corso',
      );

      final id = data?['id'];

      if (id is int) {
        await _cache.setString(chiaveInSospeso, '$id');

        return id;
      }
    } on Object catch (e) {
      // ⚠️ Un guasto qui non deve impedire di scrivere un piatto nuovo: al
      // peggio si perde il recupero di una stima vecchia.
      debugPrint('StimeInCoda.inSospeso: $e');
    }

    return null;
  }

  Future<void> dimentica() => _cache.remove(chiaveInSospeso);

  Future<int> _ricorda(Map<String, dynamic> data) async {
    final id = data['id'];

    if (id is! int) {
      throw const StimaFallita('id_mancante');
    }

    /*
     * 🚨 **Si scrive PRIMA di aspettare.** Fra l'accodamento e la prima
     * risposta l'app può essere chiusa — è proprio il caso che questa fase
     * deve gestire — e un id scritto dopo sarebbe un id che non c'è mai.
     */
    await _cache.setString(chiaveInSospeso, '$id');

    return id;
  }
}

/// Una stima arrivata, con il contorno che serve a farla confermare.
class StimaPronta {
  const StimaPronta({
    required this.risultato,
    required this.pasto,
    required this.daFoto,
  });

  /// La stessa forma che l'endpoint sincrono aveva con `save: false`.
  final Map<String, dynamic> risultato;

  /// 💡 Sopravvive alla cancellazione della richiesta: «pranzo» dice **quando**,
  /// non *cosa* — non è il pezzo personale.
  final String? pasto;

  final bool daFoto;
}

/// La stima non è riuscita, e il server dice **con quale codice**.
///
/// 💡 Il testo per la persona lo compone l'app: una frase italiana scritta nel
/// database del server è una frase che un domani non si traduce.
class StimaFallita implements Exception {
  const StimaFallita(this.codice);

  final String codice;

  String get perUnaPersona => switch (codice) {
    'foto_non_leggibile' => 'La foto non è arrivata. Riprova a scattarla.',
    'modello_non_risponde' ||
    'non_riuscita' => 'Non è riuscita. Riprova fra un momento.',
    _ => 'Non è riuscita. Riprova.',
  };

  @override
  String toString() => 'StimaFallita($codice)';
}

/// Ci sta mettendo troppo: **il lavoro continua**, l'attesa no.
class StimaTroppoLenta implements Exception {
  const StimaTroppoLenta();

  String get perUnaPersona =>
      'Ci sta mettendo più del previsto. Puoi chiudere: '
      'quando è pronta la ritrovi qui.';

  @override
  String toString() => 'StimaTroppoLenta()';
}
