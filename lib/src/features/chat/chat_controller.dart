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
