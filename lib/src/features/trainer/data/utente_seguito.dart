/// Una persona seguita da questo trainer — F5.1/F6 della Parte B.
class UtenteSeguito {
  const UtenteSeguito({
    required this.id,
    required this.nome,
    required this.email,
    required this.attivo,
    this.avatarUrl,
  });

  factory UtenteSeguito.fromJson(Map<String, dynamic> json) => UtenteSeguito(
    id: (json['id'] as num).toInt(),
    nome: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    // ⚠️ Di serie `true`: un campo mancante non deve far sembrare disattivate
    // tutte le persone di un trainer che apre l'app dopo un aggiornamento del
    // server. La direzione dell'assenza è «tutto normale».
    attivo: json['attivo'] as bool? ?? true,
    avatarUrl: json['avatar_url']?.toString(),
  );

  final int id;
  final String nome;
  final String email;

  /// 🚨 `false` non vuol dire «cancellato»: vuol dire **canale chiuso** (D5).
  /// Il legame resta, la storia si conserva, e si può riattivare.
  final bool attivo;

  final String? avatarUrl;
}

/// Quanti posti restano, e su che piano — il `meta` di `GET /trainer/members`.
///
/// 💡 Arriva **insieme** all'elenco e non da un endpoint suo: l'app deve poter
/// spegnere il pulsante «invita» *prima* che qualcuno lo prema. Scoprire il
/// limite dopo aver compilato un modulo fa sembrare rotto un vincolo
/// commerciale.
class PostiDelTrainer {
  const PostiDelTrainer({this.rimasti, this.limite, this.piano = 'free'});

  factory PostiDelTrainer.fromJson(Map<String, dynamic> json) =>
      PostiDelTrainer(
        rimasti: (json['posti_rimasti'] as num?)?.toInt(),
        limite: (json['limite'] as num?)?.toInt(),
        piano: json['piano']?.toString() ?? 'free',
      );

  /// `null` = senza limite.
  final int? rimasti;
  final int? limite;
  final String piano;

  bool get illimitato => limite == null;

  bool get puoInvitare => illimitato || (rimasti ?? 0) > 0;
}

/// L'elenco e i posti, insieme.
class MieiUtenti {
  const MieiUtenti({required this.utenti, required this.posti});

  final List<UtenteSeguito> utenti;
  final PostiDelTrainer posti;
}
