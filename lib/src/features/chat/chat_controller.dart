import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Una conversazione nell'elenco — A7.1.
class Conversation {
  const Conversation({
    required this.id,
    required this.withName,
    required this.unread,
    this.lastMessageAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    id: (j['id'] as num).toInt(),
    withName: (j['with'] as Map?)?['name']?.toString() ?? '—',
    unread: (j['unread'] as num?)?.toInt() ?? 0,
    lastMessageAt: DateTime.tryParse(j['last_message_at']?.toString() ?? ''),
  );

  final int id;
  final String withName;
  final int unread;
  final DateTime? lastMessageAt;
}

/// Un messaggio — A7.2.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: (j['id'] as num).toInt(),
    senderId: (j['sender_id'] as num).toInt(),
    body: j['body']?.toString() ?? '',
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
  );

  final int id;
  final int senderId;
  final String body;
  final DateTime? createdAt;
}

/// Una persona a cui si può scrivere — C22.
class ChatContact {
  const ChatContact({
    required this.id,
    required this.name,
    required this.isTrainer,
    this.avatarUrl,
  });

  factory ChatContact.fromJson(Map<String, dynamic> j) => ChatContact(
    id: (j['id'] as num).toInt(),
    name: j['name']?.toString() ?? '',
    isTrainer: j['is_trainer'] == true,
    avatarUrl: j['avatar_url']?.toString(),
  );

  final int id;
  final String name;
  final bool isTrainer;
  final String? avatarUrl;

  /// «Il tuo trainer» invece del solo nome: in palestra si conosce il ruolo,
  /// non sempre il cognome.
  String get ruolo => isTrainer ? 'Il tuo trainer' : 'Segui il suo allenamento';
}

/// Chi posso contattare.
///
/// 🚨 **Senza questo, la chat era una stanza in cui non si poteva entrare.**
/// `POST /conversations` vuole l'id della persona, e l'app non aveva nessun
/// modo di saperlo: chi non aveva già una conversazione vedeva una schermata
/// vuota e nessun modo di cominciarne una.
final chatContactsProvider = FutureProvider.autoDispose<List<ChatContact>>((ref) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<List<dynamic>>('/conversations/contacts');

  return data
      .map((e) => ChatContact.fromJson((e as Map).cast<String, dynamic>()))
      .toList();
});

/// Apre (o ritrova) la conversazione con una persona, e ne dà l'id.
///
/// ⚠️ Il server è idempotente: `Conversation::between()` non ne crea una
/// seconda se esiste già. Chi tocca due volte lo stesso trainer non si ritrova
/// due fili con la stessa persona — che è il modo più rapido per perdere metà
/// dei messaggi.
final apriConversazioneProvider = Provider<Future<int> Function(int)>((ref) {
  return (int userId) async {
    final data = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>('/conversations', body: {'user_id': userId});

    ref.invalidate(conversationsProvider);

    return (data['id'] as num).toInt();
  };
});

final conversationsProvider = FutureProvider.autoDispose<List<Conversation>>((ref) async {
  final data = await ref.watch(apiClientProvider).get<List<dynamic>>('/conversations');

  return data.map((e) => Conversation.fromJson((e as Map).cast<String, dynamic>())).toList();
});

/// Il filo di una conversazione, **con il polling** — A7.4 / ADR-A04.
///
/// 🚨 **Il polling non è un ripiego temporaneo: è il contratto.**
/// Su rete mobile il WebSocket spesso non si apre, e su staging non c'è nemmeno
/// un processo Reverb avviato. Una chat che «non arriva» distrugge la fiducia
/// nel prodotto più di quasi ogni altro guasto, quindi la strada che funziona
/// sempre è quella predefinita e il socket è l'ottimizzazione.
///
/// Il polling chiede **solo il nuovo** (`?after=`): riscaricare il filo intero
/// ogni quindici secondi lo renderebbe inutilizzabile con qualche centinaio di
/// messaggi.
class ThreadController extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  ThreadController(this._ref, this.conversationId) : super(const AsyncValue.loading()) {
    _carica();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _cercaNuovi());
  }

  final Ref _ref;
  final int conversationId;

  Timer? _timer;
  int _ultimoId = 0;

  Future<void> _carica() async {
    try {
      final data = await _ref
          .read(apiClientProvider)
          .get<List<dynamic>>('/conversations/$conversationId/messages');

      final messaggi = data
          .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      _ultimoId = messaggi.isEmpty ? 0 : messaggi.last.id;
      state = AsyncValue.data(messaggi);

      unawaited(_segnaLetti());
    } on Object catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _cercaNuovi() async {
    // Se il primo caricamento non è ancora riuscito, non si accumula polling
    // su un errore: si riprova solo quando c'è già qualcosa.
    if (!state.hasValue) return;

    try {
      final data = await _ref
          .read(apiClientProvider)
          .get<List<dynamic>>(
            '/conversations/$conversationId/messages',
            query: {'after': _ultimoId},
          );

      if (data.isEmpty) return;

      final nuovi = data
          .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      _ultimoId = nuovi.last.id;
      state = AsyncValue.data([...state.value ?? const [], ...nuovi]);

      unawaited(_segnaLetti());
    } on Object {
      // Un polling fallito è silenzioso: mostrare un errore ogni quindici
      // secondi perché l'ascensore non prende sarebbe peggio del problema.
    }
  }

  Future<void> invia(String testo) async {
    final pulito = testo.trim();

    if (pulito.isEmpty) return;

    final data = await _ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/conversations/$conversationId/messages',
          body: {'body': pulito},
        );

    final messaggio = ChatMessage.fromJson(data);

    _ultimoId = messaggio.id;
    state = AsyncValue.data([...state.value ?? const [], messaggio]);
  }

  Future<void> _segnaLetti() async {
    try {
      await _ref.read(apiClientProvider).post<dynamic>('/conversations/$conversationId/read');
    } on Object {
      // Non è critico: al prossimo giro ci riprova.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final threadProvider = StateNotifierProvider.autoDispose
    .family<ThreadController, AsyncValue<List<ChatMessage>>, int>(
      ThreadController.new,
    );
