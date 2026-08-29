/// Gli errori dell'API, tradotti una volta sola — A1.3.
///
/// 🚨 **Nessuna schermata deve mai vedere un `DioException`.**
/// Se l'interfaccia ragionasse sui codici HTTP, la stessa `switch` finirebbe
/// copiata in venti schermate — e basta dimenticarne una perché all'utente
/// compaia «Errore 422» invece di sapere cosa fare. La traduzione avviene
/// nell'interceptor, e da lì in poi si ragiona su questi tipi.
library;

/// Radice di tutti gli errori che l'app sa gestire.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  /// Il testo da mostrare all'utente. **Già in italiano e già comprensibile**:
  /// se una schermata deve riscriverlo, questa classe ha fallito.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Il telefono non ha rete, o il server non risponde.
class NetworkException extends ApiException {
  const NetworkException([
    super.message =
        'Non riesco a raggiungere il server. Controlla la connessione.',
  ]);
}

/// 401 — la sessione non vale più.
///
/// Non è un errore da mostrare: è un evento che porta alla schermata di
/// accesso. Chi lo cattura lo trasforma in un cambio di rotta, non in un
/// messaggio.
class UnauthenticatedException extends ApiException {
  const UnauthenticatedException([super.message = 'Sessione scaduta.']);
}

/// 403 con `code: tenant_inactive` — la palestra è sospesa.
///
/// 🚨 Va distinto dal 401: l'utente **ha** le credenziali giuste e non può
/// farci niente. Mandarlo alla schermata di accesso lo farebbe riprovare
/// all'infinito con la password corretta, convinto di sbagliarla.
class GymInactiveException extends ApiException {
  const GymInactiveException([
    super.message = 'La tua palestra ha sospeso il servizio. Rivolgiti a loro.',
  ]);
}

/// 403 con `code: trainer_subscription_expired` — 3b-U.3.1, 29/08/2026.
///
/// ══ 🚨 PERCHE' HA UNA CLASSE SUA ═══════════════════════════════════════════
///
/// 📌 *«è una merda se esce solo un errore, si deve capire che è perché non ha
/// pagato»* — il committente.
///
/// ⛔ Come [ForbiddenException] generico diventava *«Non hai accesso a questa
/// cosa»*, che a un trainer che ha usato quella schermata per mesi **sembra un
/// guasto**: riproverebbe, riavvierebbe l'app, e finirebbe per scrivere che
/// «non funziona più niente».
///
/// ⚠️ E non è come [GymInactiveException]: lì la palestra ha sospeso il
/// servizio e la persona non può farci niente. Qui **può**: rinnovare.
///
/// 💡 Il messaggio arriva dal server e dice anche cosa **non** si perde — le
/// schede restano sue. Un trainer che vede sparire «i miei utenti» pensa di
/// aver perso il lavoro di mesi.
class AbbonamentoTrainerScadutoException extends ApiException {
  const AbbonamentoTrainerScadutoException([
    super.message =
        'Il tuo abbonamento da trainer è scaduto. Le tue schede restano tue: '
        'puoi continuare a usarle come chiunque altro.',
  ]);

  /// 🚨 Il contratto col server. Si riconosce **questo**, non la frase: una
  /// virgola corretta un giorno non deve far tornare l'errore generico.
  static const codice = 'trainer_subscription_expired';
}

/// 403 generico.
class ForbiddenException extends ApiException {
  const ForbiddenException([super.message = 'Non hai accesso a questa cosa.']);
}

/// 404.
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Non trovato.']);
}

/// 422 — la validazione del backend.
///
/// Porta gli errori **per campo**, così un modulo può metterli sotto la casella
/// giusta invece di mostrare un elenco in cima.
class ValidationException extends ApiException {
  const ValidationException(super.message, this.errors);

  /// `{'email': ['già registrata'], …}`
  final Map<String, List<String>> errors;

  /// Il primo errore di un campo, se c'è.
  String? forField(String field) => errors[field]?.firstOrNull;
}

/// 429 sulla quota AI della palestra.
///
/// 🚨 Diverso da `RateLimitedException`: **non si sblocca riprovando**. L'app
/// deve smettere di proporre le funzioni AI, non mostrare un contatore.
class AiQuotaExceededException extends ApiException {
  const AiQuotaExceededException(super.message, this.resetsAt);

  /// Quando riparte il conteggio. `null` se il server non lo dice.
  final DateTime? resetsAt;
}

/// 429 generico o 503 dal fornitore AI: si può riprovare.
class RateLimitedException extends ApiException {
  const RateLimitedException(super.message, this.retryAfter);

  final Duration? retryAfter;
}

/// 5xx, o una risposta che non ha la forma attesa.
/// 🆕 L'app è troppo vecchia per parlare con questo server — FASE 10.
///
/// ══ 🚨 PERCHÉ HA UNA CLASSE SUA ═══════════════════════════════════════════
///
/// Perché il `catch (Object)` che sta in mezza app la trasformerebbe in
/// *«non ha funzionato, riprova»* — e la persona **riproverebbe per sempre**,
/// perché riprovare non può funzionare: quello che serve è aggiornare.
///
/// ⚠️ E non è un `ForbiddenException`: quello è il cancello del consenso, che è
/// un'altra cosa e ha un'altra schermata.
class AppDaAggiornareException extends ApiException {
  const AppDaAggiornareException(super.message, {this.store});

  /// 💡 Lo manda **il server**: il giorno che l'identificativo del pacchetto
  /// cambia, le copie già installate manderebbero la gente sulla scheda
  /// sbagliata — e sono proprio quelle che non si possono aggiornare.
  final String? store;
}

class ServerException extends ApiException {
  const ServerException([
    super.message = 'Il servizio ha avuto un problema. Riprova fra poco.',
  ]);
}
