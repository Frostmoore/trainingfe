import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../errors/api_exception.dart';
import '../storage/token_store.dart';
import 'identita_app.dart';

/// Il client HTTP dell'app — A1.3.
///
/// 🚨 **Tutta la rete passa da qui.** Tre cose che, sparse nelle schermate, non
/// verrebbero mai fatte bene:
///
///  1. **il token su ogni richiesta**, aggiunto in un punto solo: basta
///     dimenticarlo una volta per avere una schermata che dà 401 senza motivo
///     apparente;
///  2. **la traduzione degli errori** in `ApiException`, così nessuna
///     schermata ragiona su codici HTTP;
///  3. **il 401 che invalida la sessione**, notificato una volta sola a chi di
///     dovere invece di essere gestito venti volte.
class ApiClient {
  ApiClient({
    required AppConfig config,
    required TokenStore tokenStore,
    Dio? dio,
  }) // `prefer_initializing_formals` non è applicabile: un parametro **con
    // nome** non può chiamarsi come un campo privato, e rendere il campo
    // pubblico solo per soddisfare il lint aprirebbe l'accesso al token
    // store dall'esterno.
    // ignore: prefer_initializing_formals
    : _tokenStore = tokenStore,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: config.apiBaseUrl,
               // Timeout espliciti e corti: il default di Dio è *nessun*
               // timeout di risposta, e su rete mobile che va e viene questo
               // significa uno spinner che gira per sempre.
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
               sendTimeout: const Duration(seconds: 60),
               headers: const {
                 'Accept': 'application/json',
                 // Senza questo Laravel risponde con un redirect HTML invece
                 // che con un JSON su alcuni errori di autenticazione.
                 'X-Requested-With': 'XMLHttpRequest',
               },
               // Gli errori li traduciamo noi: `validateStatus` lascia passare
               // tutto fino all'interceptor, che decide.
               validateStatus: (status) => status != null && status < 500,
             ),
           ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  final Dio _dio;
  final TokenStore _tokenStore;

  final _sessionExpired = StreamController<void>.broadcast();

  /// 🆕 L'app è troppo vecchia — FASE 10.
  ///
  /// 🚨 Uno stream e non un'eccezione da catturare in ogni schermata, per la
  /// stessa ragione già scritta per il 401: **la prima schermata che se ne
  /// dimenticasse** lascerebbe la persona davanti a un errore generico su
  /// un'app che non può funzionare, e le farebbe premere «riprova» all'infinito.
  final _daAggiornare = StreamController<AppDaAggiornareException>.broadcast();

  /// Emette quando il server dice che la sessione non vale più.
  ///
  /// È uno stream e non una callback perché ad ascoltarlo sono due cose
  /// diverse: il router (che porta al login) e lo stato di autenticazione (che
  /// dimentica l'utente). Con una callback sola, una delle due resterebbe
  /// scoperta.
  Stream<void> get onSessionExpired => _sessionExpired.stream;

  Stream<AppDaAggiornareException> get onDaAggiornare => _daAggiornare.stream;

  Dio get raw => _dio;

  /// Estrae l'`ApiException` da qualunque cosa sia stata lanciata.
  ///
  /// 🚨 Serve perché `dio` avvolge il nostro errore dentro un `DioException`:
  /// senza questo metodo ogni `catch` dovrebbe scrivere
  /// `(e as DioException).error`, e chi se lo dimentica finisce a riconoscere
  /// gli errori dal testo del messaggio — cioè a rompersi il giorno in cui
  /// qualcuno riformula una frase.
  static ApiException unwrapError(Object error) {
    if (error is ApiException) return error;

    if (error is DioException) {
      final inner = error.error;

      if (inner is ApiException) return inner;
    }

    return const ServerException();
  }

  // ───────────────────────── verbi ─────────────────────────

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool unwrap = true,
  }) async {
    final response = await _dio.get<dynamic>(path, queryParameters: query);

    return _unwrap<T>(response, unwrap);
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool unwrap = true,
  }) async {
    final response = await _dio.post<dynamic>(
      path,
      data: body,
      queryParameters: query,
    );

    return _unwrap<T>(response, unwrap);
  }

  Future<T> patch<T>(String path, {Object? body, bool unwrap = true}) async {
    final response = await _dio.patch<dynamic>(path, data: body);

    return _unwrap<T>(response, unwrap);
  }

  /// PUT — sostituisce la risorsa per intero.
  ///
  /// ⚠️ Distinta da `patch` di proposito: il backend usa PUT per le schede
  /// (dove le righe si riscrivono tutte) e PATCH per il profilo (dove si salva
  /// un campo alla volta). Confonderle significherebbe azzerare ciò che non si
  /// è mandato, o non riscrivere ciò che si voleva sostituire.
  Future<T> put<T>(String path, {Object? body, bool unwrap = true}) async {
    final response = await _dio.put<dynamic>(path, data: body);

    return _unwrap<T>(response, unwrap);
  }

  /// La DELETE accetta un corpo.
  ///
  /// ⚠️ Serve a `DELETE /account`, che richiede la password come conferma. È
  /// insolito ma legittimo (HTTP non lo vieta) e l'alternativa — la password in
  /// query string — la scriverebbe nei log del server e nella cronologia dei
  /// proxy.
  Future<void> delete(String path, {Object? body}) async {
    await _dio.delete<dynamic>(path, data: body);
  }

  /// Invio multipart, per le foto.
  Future<T> upload<T>(String path, FormData form, {bool unwrap = true}) async {
    final response = await _dio.post<dynamic>(path, data: form);

    return _unwrap<T>(response, unwrap);
  }

  /// Scarica byte grezzi — N13.4.
  ///
  /// 🚨 **Non passa da `_unwrap`**, e non e' una dimenticanza: la risposta
  /// non e' JSON. E' un flusso cifrato, e provare a interpretarlo come un
  /// inviluppo `{data: ...}` lo trasformerebbe in un errore di formato su byte
  /// perfettamente validi.
  Future<Uint8List> scaricaByte(String path) async {
    final risposta = await _dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );

    return Uint8List.fromList(risposta.data ?? const []);
  }

  // ───────────────────────── interni ─────────────────────────

  /// Estrae `data` dall'inviluppo del backend.
  ///
  /// Quasi ogni risposta è `{"data": …}`: srotolarlo qui evita che ogni
  /// chiamante scriva `response.data['data']`, che è il punto in cui prima o
  /// poi qualcuno scrive `response.data` e ottiene una mappa con una chiave
  /// sola.
  ///
  /// 🚨 **`unwrap: false` esiste perché le risposte di autenticazione NON sono
  /// un inviluppo.** `/auth/login`, `/auth/register` e `/auth/me` rispondono
  /// `{token, data, branding}`: `data` è **una delle tre cose**, non il
  /// contenitore. Srotolandole si ottiene il solo utente, il token sparisce, e
  /// il login fallisce con un errore che sembra «credenziali sbagliate».
  ///
  /// È costato un pomeriggio: il login dell'app **non ha mai funzionato**, per
  /// nessun utente, e il messaggio diceva una cosa falsa. Se un giorno si è
  /// tentati di rendere questo metodo «più intelligente» — per esempio
  /// srotolando solo quando `data` è l'unica chiave — la risposta è no: una
  /// regola implicita che indovina è esattamente ciò che ha nascosto il
  /// problema. Chi non vuole l'inviluppo lo dice.
  T _unwrap<T>(Response<dynamic> response, bool unwrap) {
    final body = response.data;

    if (unwrap && body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'] as T;
    }

    return body as T;
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStore.read();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    /*
     * 🆕 **Chi è questa copia dell'app** — FASE 10.2.
     *
     * 🚨 Su **ogni** richiesta e non solo all'avvio: un controllo fatto una
     * volta all'apertura si può saltare — l'app resta aperta per giorni — e nel
     * frattempo il server potrebbe aver alzato il minimo.
     *
     * 💡 `IdentitaApp` legge una volta sola e tiene: il numero non cambia
     * mentre l'app è aperta, perché per aggiornarla bisogna chiuderla.
     */
    options.headers.addAll(await IdentitaApp.intestazioni());

    handler.next(options);
  }

  /// `validateStatus` lascia passare i 4xx: qui si decide cosa farne.
  void _onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final status = response.statusCode ?? 0;

    if (status < 400) {
      handler.next(response);

      return;
    }

    handler.reject(
      DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: _translate(response),
      ),
      true,
    );
  }

  void _onError(DioException error, ErrorInterceptorHandler handler) {
    // Già tradotto da `_onResponse`: si lascia passare com'è.
    if (error.error is ApiException) {
      handler.reject(error);

      return;
    }

    final tradotto = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.connectionError => const NetworkException(),
      DioExceptionType.badResponse => _translate(error.response),
      _ => const ServerException(),
    };

    handler.reject(
      DioException(
        requestOptions: error.requestOptions,
        response: error.response,
        type: error.type,
        error: tradotto,
      ),
    );
  }

  /// La sola `switch` sui codici HTTP di tutta l'app.
  ApiException _translate(Response<dynamic>? response) {
    if (response == null) return const ServerException();

    final body = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : const <String, dynamic>{};

    final code = body['code'] ?? body['error'];
    final message = body['message'] as String?;

    switch (response.statusCode) {
      case 401:
        // 🚨 Si avvisa **una volta sola**, da qui: se ogni schermata dovesse
        // accorgersene, la prima che se ne dimentica lascerebbe l'utente in una
        // sessione morta che sembra viva.
        _sessionExpired.add(null);

        return const UnauthenticatedException();

      case 403:
        // La palestra sospesa NON è un problema di credenziali: mandare
        // l'utente al login lo farebbe riprovare all'infinito con la password
        // giusta.
        return code == 'tenant_inactive'
            ? GymInactiveException(
                message ?? const GymInactiveException().message,
              )
            : ForbiddenException(message ?? const ForbiddenException().message);

      case 404:
        return NotFoundException(message ?? const NotFoundException().message);

      /*
       * 🆕 **426 — questa versione non parla più con questo server** (FASE 10).
       *
       * 🚨 Ha una classe sua perché il `catch (Object)` che sta in mezza app la
       * trasformerebbe in «non ha funzionato, riprova» — e riprovare **non può
       * funzionare**: quello che serve è aggiornare.
       */
      case 426:
        return _annunciaCheVaAggiornata(message, body['store']?.toString());

      case 422:
        return ValidationException(
          message ?? 'Controlla i dati inseriti.',
          _parseErrors(body['errors']),
        );

      case 429:
        if (code == 'ai_quota_exceeded') {
          return AiQuotaExceededException(
            message ??
                'La tua palestra ha esaurito le funzioni AI di questo mese.',
            DateTime.tryParse(body['resets_at']?.toString() ?? ''),
          );
        }

        return RateLimitedException(
          message ?? 'Troppe richieste. Aspetta un momento.',
          _retryAfter(response),
        );

      case 503:
        return RateLimitedException(
          message ?? 'Il servizio è momentaneamente occupato.',
          _retryAfter(response),
        );

      default:
        return ServerException(message ?? const ServerException().message);
    }
  }

  Duration? _retryAfter(Response<dynamic> response) {
    final header = response.headers.value('Retry-After');
    final seconds = int.tryParse(header ?? '');

    return seconds != null ? Duration(seconds: seconds) : null;
  }

  Map<String, List<String>> _parseErrors(Object? raw) {
    if (raw is! Map) return const {};

    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        value is List
            ? value.map((e) => e.toString()).toList()
            : [value.toString()],
      ),
    );
  }

  /// 🚨 Si annuncia **una volta sola**, da qui — come per il 401.
  ///
  /// 💡 Sta in un metodo e non dentro la `switch` perché una dichiarazione in un
  /// `case` senza graffe perde di vista dove finisce, e questo `switch` è
  /// l'unico posto dell'app che traduce i codici HTTP: va tenuto leggibile.
  AppDaAggiornareException _annunciaCheVaAggiornata(
    String? messaggio,
    String? store,
  ) {
    final tradotto = AppDaAggiornareException(
      messaggio ?? 'Questa versione dell\'app non è più supportata.',
      store: store,
    );

    _daAggiornare.add(tradotto);

    return tradotto;
  }

  Future<void> dispose() async {
    await _sessionExpired.close();
    await _daAggiornare.close();
  }
}
