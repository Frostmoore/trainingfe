import 'dart:ui';

/// Il branding della palestra — ADR-A01.
///
/// È l'unica cosa che l'app scarica **prima** di autenticarsi: serve a vestirsi
/// dei colori giusti già nella schermata di accesso. Arriva da
/// `GET /api/v1/branding/lookup?code=`, che è pubblico.
class GymBranding {
  const GymBranding({
    required this.name,
    required this.slug,
    required this.primary,
    required this.secondary,
    required this.accent,
    this.logoUrl,
    this.locale = 'it',
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
      name: json['name']?.toString() ?? 'La tua palestra',
      slug: json['slug']?.toString() ?? '',
      primary: parseHex(colors['primary']?.toString()) ?? fallbackPrimary,
      secondary: parseHex(colors['secondary']?.toString()) ?? fallbackSecondary,
      accent: parseHex(colors['accent']?.toString()) ?? fallbackAccent,
      logoUrl: json['logo_url']?.toString(),
      locale: json['locale']?.toString() ?? 'it',
    );
  }

  final String name;
  final String slug;
  final Color primary;
  final Color secondary;
  final Color accent;
  final String? logoUrl;
  final String locale;

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
    'colors': {
      'primary': _hex(primary),
      'secondary': _hex(secondary),
      'accent': _hex(accent),
    },
  };

  static String _hex(Color c) =>
      '#${((c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
