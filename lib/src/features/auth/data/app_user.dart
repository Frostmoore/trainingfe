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
    this.isTrainer = false,
    this.aiAbilitata = true,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    username: json['username']?.toString(),
    avatarUrl: json['avatar_url']?.toString(),
    passwordIsSet: json['password_is_set'] != false,
    // 💡 Si ricava da `roles`, che il server manda già: nessun campo nuovo da
    // aggiungere, nessuna versione di backend da aspettare.
    // 🆕 F5/F6 — anche `free_trainer` allena: è un trainer indipendente, senza
    // una palestra alle spalle. ⚠️ Guardare solo `trainer` gli nasconderebbe
    // «i miei utenti», cioè l'unica cosa per cui usa questa applicazione.
    isTrainer: ((json['roles'] as List?) ?? const [])
        .any((r) => r == 'trainer' || r == 'free_trainer'),

    /*
     * 🚨 **Di serie `true`, e la direzione è deliberata** — F4.
     *
     * Un server vecchio non manda questo campo. Trattare l'assenza come «niente
     * AI» spegnerebbe la funzione a **tutti** gli utenti paganti nel momento in
     * cui l'app si aggiorna prima del backend — e loro non avrebbero modo di
     * capire perché.
     *
     * ⚠️ L'errore opposto costa molto meno: un pulsante che si può premere e
     * che riceve `403`. È lo stesso stato di prima di F4, non un guasto nuovo.
     *
     * 💡 E il campo qui **non è un permesso**: serve a decidere se disegnare un
     * pulsante. Il cancello vero è `RequirePlanWithAi` lato server, che
     * risponde `403` anche a un'app che ignorasse questo valore.
     */
    aiAbilitata: json['ai_enabled'] as bool? ?? true,
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

  /// Se questa persona **allena** — S7.
  ///
  /// ⚠️ **È l'unico ruolo che l'app conosce, e c'è una ragione precisa.** Il
  /// commento in cima dice che portarsi dietro i ruoli invita a duplicare lato
  /// client decisioni che il backend prende già, e resta vero. Ma qui non si sta
  /// decidendo un permesso: si sta decidendo **se disegnare un pulsante**.
  ///
  /// 🚨 Il permesso lo decide comunque il server — `GET /workout-plans/templates`
  /// risponde 403 a un iscritto anche se qualcuno gli mettesse il pulsante
  /// davanti. Questo campo serve a non mostrare un pulsante che darebbe sempre
  /// errore: un pulsante rotto fa sembrare rotta tutta l'applicazione, non solo
  /// se stesso.
  final bool isTrainer;

  /// Se il piano di questa persona comprende le funzioni con l'AI — F4.
  ///
  /// 🚨 **Serve a disegnare, non ad autorizzare.** L'app lo usa per mostrare la
  /// stima da testo e da foto **già disattivata**, con scritto perché e dove
  /// andare — invece di far compilare un modulo e poi rispondere `403`.
  ///
  /// ⚠️ Il cancello vero resta `RequirePlanWithAi` lato server: un client non
  /// decide mai i permessi, e un'app che ignorasse questo campo riceverebbe
  /// comunque un rifiuto.
  final bool aiAbilitata;

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
