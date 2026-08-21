import 'dart:ui';

import '../../auth/data/social_sign_in.dart';

/// Il branding della palestra — ADR-A01.
///
/// È l'unica cosa che l'app scarica **prima** di autenticarsi: serve a vestirsi
/// dei colori giusti già nella schermata di accesso. Arriva da
/// `GET /api/v1/branding/lookup?code=`, che è pubblico.
class GymBranding {
  const GymBranding({
    this.name,
    required this.slug,
    required this.primary,
    required this.secondary,
    required this.accent,
    this.logoUrl,
    this.locale = 'it',
    this.social = const [],
  });

  /// 🚨 **Tollerante per costruzione.**
  ///
  /// Questa mappa arriva anche dalla cache su disco, che può essere stata
  /// scritta da una versione precedente dell'app. Un campo mancante non deve
  /// far fallire l'avvio: l'utente non avrebbe nessun modo di rimediare se non
  /// disinstallando. Quindi ogni campo ha un valore di riserva.
  factory GymBranding.fromJson(Map<String, dynamic> json) {
    final colors = json['colors'] is Map
        ? (json['colors'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    return GymBranding(
      /*
       * 🚨 **`null` è una risposta, non un dato mancante** — F3.
       *
       * Dal backend `branding.name` arriva `null` per un **tenant personale**:
       * chi si è iscritto senza codice palestra non ha un'insegna da mostrare,
       * e il nome del suo tenant è il **suo** nome.
       *
       * ⚠️ Il valore di riserva di prima — «La tua palestra» — qui sarebbe
       * peggio del vuoto: scriverebbe in cima alla schermata il nome di una
       * palestra che non esiste, a una persona che ha scelto di non averne una.
       *
       * 💡 Resta la differenza fra le due assenze: `null` dal server significa
       * «non ne ha una», mentre una cache vecchia senza il campo dà anch'essa
       * `null` — e il risultato voluto è lo stesso, cioè non disegnare niente.
       */
      name: json['name']?.toString(),
      slug: json['slug']?.toString() ?? '',
      primary: parseHex(colors['primary']?.toString()) ?? fallbackPrimary,
      secondary: parseHex(colors['secondary']?.toString()) ?? fallbackSecondary,
      accent: parseHex(colors['accent']?.toString()) ?? fallbackAccent,
      logoUrl: json['logo_url']?.toString(),
      locale: json['locale']?.toString() ?? 'it',
      // ⚠️ Assente su una cache scritta da una versione precedente, e va bene
      // così: nessun pulsante, che è lo stesso esito di «non configurato».
      social: ((json['social'] as List?) ?? const [])
          .map((e) => e.toString())
          .where(SocialProviderId.esiste)
          .toList(growable: false),
    );
  }

  /// 🚨 `null` quando **non c'è una palestra**: un tenant personale non ha
  /// un'insegna, e il suo nome è quello della persona. Chi lo disegna deve
  /// trattarlo come un'assenza da non riempire, non come un dato mancante da
  /// sostituire con un valore di ripiego.
  final String? name;

  final String slug;
  final Color primary;
  final Color secondary;
  final Color accent;
  final String? logoUrl;
  final String locale;

  /// I fornitori esterni con cui si può accedere: `google`, `apple` — C17.
  ///
  /// 🚨 **Lo decide il server.** L'elenco è vuoto finché le credenziali non
  /// sono configurate lato backend, e allora l'app non disegna nessun pulsante.
  /// Un «Accedi con Apple» che risponde sempre errore fa sembrare rotta tutta
  /// l'applicazione, non solo quel pulsante.
  final List<String> social;

  bool supporta(String provider) => social.contains(provider);

  /// Se dietro questo branding c'e' **davvero una palestra** — difetto del
  /// 21/08/2026.
  ///
  /// == 🚨 PERCHE' NON BASTA GUARDARE IL NOME =================================
  ///
  /// ⚠️ Il controllo ovvio — `name != null && name!.isNotEmpty` — era scritto in
  /// **quattro punti** e in tutti e quattro **dava il risultato sbagliato**:
  /// [neutral] ha `name: 'Training Companion'`, che e' un nome non vuoto a tutti
  /// gli effetti. Cosi' chi non ha nessuna palestra risultava averne una che si
  /// chiama come l'app.
  ///
  /// 🚨 Le conseguenze non erano cosmetiche: l'intestazione scriveva «Training
  /// Companion» al posto del nome della persona (3b-O.1a.3), e il colore
  /// d'accento scelto nelle impostazioni **non veniva applicato**, perche'
  /// `app.dart` lo riserva a chi non ha una palestra.
  ///
  /// 💡 Il discriminante giusto e' lo **slug**: [neutral] ce l'ha vuoto per
  /// costruzione, e una palestra vera ce l'ha sempre — e' la chiave con cui il
  /// backend la trova. Il nome no: e' facoltativo di la', e riempito qui.
  ///
  /// 🚨 Chiunque debba chiedersi «c'e' una palestra?» usa **questo** e non il
  /// nome, altrimenti il difetto rinasce dal quinto punto in poi.
  bool get haPalestra => slug.isNotEmpty && (name?.isNotEmpty ?? false);

  /// 🆕 Una copia con un colore diverso — 3b-O.1a.1.
  ///
  /// 💡 Serve a chi **non ha una palestra** e ha scelto il proprio accento: il
  /// tema si costruisce da `primary`, e cambiarlo qui evita di infilare una
  /// seconda strada dentro `AppTheme`. ⚠️ Il resto — nome, logo, social — resta
  /// quello che era: si sostituisce **un colore**, non l'identità.
  GymBranding copyWith({Color? primary}) => GymBranding(
    name: name,
    slug: slug,
    primary: primary ?? this.primary,
    secondary: secondary,
    accent: accent,
    logoUrl: logoUrl,
    locale: locale,
    social: social,
  );

  /// I colori di riserva: gli stessi che il backend usa come default sui
  /// `tenants`, così una palestra che non li ha impostati non si vede diversa
  /// fra app e pannello.
  static const fallbackPrimary = Color(0xFF0F766E);
  static const fallbackSecondary = Color(0xFF6B7280);
  static const fallbackAccent = Color(0xFFF59E0B);

  /// Il branding neutro, quando ancora non si sa a che palestra si appartiene.
  static const neutral = GymBranding(
    name: 'Training Companion',
    slug: '',
    primary: fallbackPrimary,
    secondary: fallbackSecondary,
    accent: fallbackAccent,
  );

  /// `#RRGGBB` → `Color`, o `null` se non è un colore.
  ///
  /// 🚨 Restituire `null` invece di un colore a caso è quello che permette al
  /// chiamante di usare il proprio valore di riserva: un `#GGGGGG` scritto per
  /// sbaglio nel pannello renderebbe altrimenti l'app di un colore casuale, o
  /// la farebbe esplodere all'avvio.
  static Color? parseHex(String? hex) {
    if (hex == null) return null;

    final clean = hex.trim().replaceFirst('#', '');

    if (clean.length != 6) return null;

    final value = int.tryParse(clean, radix: 16);

    return value == null ? null : Color(0xFF000000 | value);
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'slug': slug,
    'logo_url': logoUrl,
    'locale': locale,
    'social': social,
    'colors': {
      'primary': _hex(primary),
      'secondary': _hex(secondary),
      'accent': _hex(accent),
    },
  };

  static String _hex(Color c) =>
      '#${((c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
