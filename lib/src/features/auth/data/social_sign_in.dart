/// L'accesso con Google e Apple, lato app — C17.
///
/// ⏸️ **Manca un pezzo solo, ed è dichiarato.** Tutto il resto esiste: il
/// backend verifica i token, collega gli account e risponde; l'app sa quando
/// mostrare i pulsanti e cosa fare con il token. Quello che non c'è è **chi
/// ottiene il token dal sistema operativo**, perché richiede i pacchetti
/// (`google_sign_in`, `sign_in_with_apple`) e le credenziali nelle console di
/// Google e Apple — cioè lavoro che si fa una volta sola, con gli account veri
/// davanti.
///
/// 🚨 **Fino ad allora i pulsanti non compaiono affatto**, perché il server non
/// dichiara nessun fornitore (`GymBranding.social` resta vuoto). Non c'è nessun
/// pulsante morto da premere: è la ragione per cui la disponibilità la decide il
/// backend e non una costante qui dentro.
///
/// Quando sarà il momento, l'unica cosa da fare è sostituire
/// `SocialSignIn.instance` con un'implementazione vera — la firma non cambia.
library;

/// I fornitori conosciuti. Le stringhe sono quelle del backend
/// (`App\Enums\SocialProvider`): cambiarne una qui le disallinea.
class SocialProviderId {
  const SocialProviderId._();

  static const google = 'google';
  static const apple = 'apple';

  static const tutti = [google, apple];

  static bool esiste(String id) => tutti.contains(id);

  static String etichetta(String id) => switch (id) {
    google => 'Google',
    apple => 'Apple',
    _ => id,
  };
}

/// Il token restituito dal sistema operativo, pronto da mandare al server.
class SocialCredential {
  const SocialCredential({required this.provider, required this.idToken});

  final String provider;
  final String idToken;
}

/// Chi ottiene il token dal sistema operativo.
abstract class SocialSignIn {
  /// Apre la finestra del fornitore e restituisce il token d'identità.
  ///
  /// `null` quando la persona annulla — che **non** è un errore e non va
  /// mostrato come tale: chi cambia idea non ha sbagliato niente.
  Future<SocialCredential?> accedi(String provider);

  /// 🚨 L'implementazione attiva. Va sostituita, non modificata.
  static SocialSignIn instance = const _NonInstallato();
}

/// Il segnaposto, finché i pacchetti non ci sono.
///
/// ⚠️ **Lancia con un messaggio che dice esattamente cosa manca.** Un segnaposto
/// che restituisce `null` in silenzio farebbe sembrare che l'utente abbia
/// annullato, e si passerebbe un pomeriggio a cercare il difetto nel posto
/// sbagliato.
class _NonInstallato implements SocialSignIn {
  const _NonInstallato();

  @override
  Future<SocialCredential?> accedi(String provider) {
    throw UnimplementedError(
      'Accesso con ${SocialProviderId.etichetta(provider)} non ancora collegato: '
      'mancano i pacchetti google_sign_in / sign_in_with_apple e le credenziali. '
      'Sostituisci SocialSignIn.instance. Il backend è già pronto.',
    );
  }
}
