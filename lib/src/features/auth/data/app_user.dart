/// L'utente autenticato, come lo restituisce `GET /api/v1/auth/me`.
///
/// Volutamente povero: l'app degli iscritti ha bisogno di sapere **chi è** e
/// **di quale palestra**, non di conoscere ruoli e permessi. Un iscritto non
/// entra in nessun pannello, e portarsi dietro i ruoli inviterebbe a scrivere
/// interfacce condizionate su di essi — cioè a duplicare lato client decisioni
/// che il backend prende già.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.username,
    this.avatarUrl,
    this.tenantName,
    this.passwordIsSet = true,
    this.social = const [],
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    username: json['username']?.toString(),
    avatarUrl: json['avatar_url']?.toString(),
    passwordIsSet: json['password_is_set'] != false,
    social: ((json['social'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(growable: false),
    tenantName: json['tenant'] is Map
        ? (json['tenant'] as Map)['name']?.toString()
        : json['tenant_name']?.toString(),
  );

  final int id;
  final String name;
  final String email;
  final String? username;
  final String? avatarUrl;
  final String? tenantName;

  /// Se questa persona ha una password **che conosce** — G8.
  ///
  /// 🚨 Falso per chi entra con Google o Apple: ne ha una, ma casuale e mai
  /// vista. Mostrargli «cambia password» vorrebbe dire chiedergli quella
  /// attuale — un modulo che non può compilare e che sembra un guasto.
  ///
  /// ⚠️ Il default è `true`, non `false`: una risposta vecchia senza il campo
  /// viene da un account nato con email e password, e nascondergli la funzione
  /// sarebbe l'errore peggiore dei due.
  final bool passwordIsSet;

  /// I fornitori esterni collegati: `google`, `apple`.
  final List<String> social;

  /// Le iniziali per l'avatar quando non c'è una foto.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();

    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

extension on String {
  Iterable<String> get characters => split('');
}
