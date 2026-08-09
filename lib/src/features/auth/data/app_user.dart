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
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    username: json['username']?.toString(),
    avatarUrl: json['avatar_url']?.toString(),
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
