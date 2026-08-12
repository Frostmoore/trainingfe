import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../core/crypto/busta_messaggio.dart';
import '../../core/crypto/contenuto_messaggio.dart';
import '../../core/crypto/providers_crypto.dart';
import '../../core/crypto/servizio_chiavi.dart';
import '../../core/providers.dart';

/// L'altra persona non ha ancora pubblicato una chiave.
///
/// ⚠️ Vuol dire che non ha mai aperto l'app dopo l'arrivo della chat cifrata.
/// Non è un errore da nascondere: senza la sua chiave **non le si può
/// scrivere**, e un messaggio mandato lo stesso non lo leggerebbe nessuno.
class ChatSenzaChiave implements Exception {
  const ChatSenzaChiave();

  @override
  String toString() =>
      'Questa persona non ha ancora aperto l\'app: non puoi ancora scriverle.';
}

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
    // A3: l'ora dell'ultimo messaggio va mostrata nel fuso di chi legge.
    lastMessageAt: DateTime.tryParse(
      j['last_message_at']?.toString() ?? '',
    )?.toLocal(),
  );

  final int id;
  final String withName;
  final int unread;
  final DateTime? lastMessageAt;
}

/// Un messaggio, già decifrato — A7.2 / S6.5.
///
/// 🚨 **`body` non arriva più leggibile dalla rete.** Il server conserva una
/// busta cifrata fra i due telefoni; il testo che sta qui dentro esiste solo
/// dopo che [ThreadController] l'ha aperta con la chiave di questo dispositivo.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    this.createdAt,
    this.leggibile = true,
    this.contenuto,
  });

  final int id;
  final int senderId;

  /// Il testo in chiaro, oppure la spiegazione se non si è potuto aprire.
  ///
  /// 💡 Per una scheda è il **titolo**: serve all'anteprima nell'elenco, dove
  /// una riga di JSON non direbbe niente a nessuno.
  final String body;

  /// Cosa c'era davvero dentro la busta — S7.
  ///
  /// `null` sui messaggi che non si è potuto aprire. ⚠️ È questo, e non `body`,
  /// che l'interfaccia deve guardare per decidere se disegnare una nuvoletta o
  /// una scheda con il pulsante «Aggiungi alle mie schede».
  final ContenutoMessaggio? contenuto;

  final DateTime? createdAt;

  /// ⚠️ **Falso non vuol dire «attacco».** Il caso di gran lunga più comune è
  /// un messaggio cifrato verso una chiave che non c'è più, perché l'altra
  /// persona ha perso la propria chiave maestra e ne ha generata una nuova.
  /// L'interfaccia deve dirlo così, non gridare alla manomissione.
  final bool leggibile;

  /// Il messaggio che non si è potuto aprire.
  ///
  /// 💡 Si mostra **al posto** del testo e non si nasconde la riga: sapere che
  /// «qui c'era un messaggio che non riesco a leggere» è un'informazione utile,
  /// mentre una riga sparita fa solo pensare che l'altro non abbia risposto.
  factory ChatMessage.illeggibile({
    required int id,
    required int senderId,
    DateTime? createdAt,
  }) => ChatMessage(
    id: id,
    senderId: senderId,
    body: 'Questo messaggio non è più leggibile su questo dispositivo.',
    createdAt: createdAt,
    leggibile: false,
  );
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

  ServizioChiavi? _chiavi;
  KeyPair? _mia;
  ChiavePubblica? _sua;

  /// L'impronta da leggersi a voce, quando le chiavi sono note.
  ///
  /// 🚨 È l'unica difesa contro l'attacco che questo schema non ferma da solo:
  /// **le chiavi pubbliche le distribuisce il nostro server**, che potrebbe
  /// darne una propria a entrambi e mettersi in mezzo. I conti tornerebbero lo
  /// stesso — sarebbero solo le chiavi sbagliate.
  String? get impronta => _mia == null || _sua == null
      ? null
      : _chiavi!.cifratura.improntaDiSicurezza(_mia!.publicKey, _sua!.byte);

  /// Prende le due chiavi, una volta per conversazione.
  ///
  /// ⚠️ Se l'altra persona non ha ancora una chiave, `_sua` resta `null` e la
  /// schermata deve dire *«non puoi ancora scrivergli»*: cifrare verso il nulla
  /// produrrebbe un messaggio che nessuno potrà mai leggere.
  Future<void> _preparaChiavi() async {
    if (_mia != null) return;

    _chiavi = await _ref.read(servizioChiaviProvider.future);
    _mia = await _chiavi!.identita();
    _sua = await _chiavi!.chiaveDellAltro(conversationId);
  }

  /// Apre una busta, o restituisce il messaggio segnaposto.
  ChatMessage _apri(Map<String, dynamic> j) {
    final id = (j['id'] as num).toInt();
    final mittente = (j['sender_id'] as num).toInt();
    // A3: l'orario sotto la nuvoletta e' quello dell'orologio di chi legge.
    final quando = DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal();

    if (_sua == null) {
      return ChatMessage.illeggibile(id: id, senderId: mittente, createdAt: quando);
    }

    try {
      final chiaro = _chiavi!.cifratura.decifra(
        busta: BustaMessaggio.daApi(j),
        mieSegrete: _mia!.secretKey,
        suaPubblica: _sua!.byte,
      );

      final contenuto = ContenutoMessaggio.daChiaro(chiaro);

      return ChatMessage(
        id: id,
        senderId: mittente,
        body: switch (contenuto) {
          ContenutoTesto(:final testo) => testo,
          ContenutoScheda(:final titolo) => titolo,
          ContenutoPianoAlimentare(:final titolo) => titolo,
          ContenutoSconosciuto() =>
            'Questo messaggio richiede una versione più recente dell\'app.',
        },
        contenuto: contenuto,
        createdAt: quando,
      );
    } on Object {
      // 🚨 Qualunque cosa vada storta qui — MAC che non torna, base64
      // malformato, versione sconosciuta — **non deve far sparire il filo**.
      // Una singola busta illeggibile è un caso normale; una schermata che
      // esplode per un messaggio su duecento no.
      return ChatMessage.illeggibile(id: id, senderId: mittente, createdAt: quando);
    }
  }

  Future<void> _carica() async {
    try {
      await _preparaChiavi();

      final data = await _ref
          .read(apiClientProvider)
          .get<List<dynamic>>('/conversations/$conversationId/messages');

      final messaggi = data
          .map((e) => _apri((e as Map).cast<String, dynamic>()))
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
          .map((e) => _apri((e as Map).cast<String, dynamic>()))
          .toList();

      _ultimoId = nuovi.last.id;
      state = AsyncValue.data([...state.value ?? const [], ...nuovi]);

      unawaited(_segnaLetti());
    } on Object {
      // Un polling fallito è silenzioso: mostrare un errore ogni quindici
      // secondi perché l'ascensore non prende sarebbe peggio del problema.
    }
  }

  /// Cifra e manda.
  ///
  /// 🚨 **Si cifra qui, prima della rete.** Non esiste nessun percorso in cui il
  /// testo in chiaro lasci questo telefono: il server rifiuta i messaggi senza
  /// busta (422), quindi anche un errore di programmazione fallirebbe
  /// rumorosamente invece di mandare in chiaro.
  ///
  /// ⚠️ Lancia [ChatSenzaChiave] se l'altra persona non ne ha ancora una.
  Future<void> invia(String testo) async {
    final pulito = testo.trim();

    if (pulito.isEmpty) return;

    await inviaContenuto(ContenutoTesto(pulito));
  }

  /// Manda **qualunque cosa** il canale sappia trasportare — S7.
  ///
  /// 🎯 Una scheda passa esattamente per di qui: non c'è nessun endpoint nuovo,
  /// nessun caricamento a parte, nessun permesso in più. Il server continua a
  /// instradare buste senza sapere che una di esse è un programma di
  /// allenamento — ed è la prova che S6 non era un costo, ma l'infrastruttura
  /// su cui questo si appoggia gratis.
  Future<void> inviaContenuto(ContenutoMessaggio contenuto) async {
    await _preparaChiavi();

    if (_sua == null) throw const ChatSenzaChiave();

    final busta = _chiavi!.cifratura.cifra(
      testo: contenuto.perLaBusta(),
      mieSegrete: _mia!.secretKey,
      suaPubblica: _sua!.byte,
    );

    final data = await _ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/conversations/$conversationId/messages',
          body: busta.perApi(),
        );

    // 💡 Il messaggio appena scritto si rilegge **dalla stessa identica busta**:
    // il segreto condiviso è lo stesso calcolato da una parte o dall'altra. È il
    // motivo per cui il server non deve conservare una seconda copia cifrata per
    // il mittente.
    final messaggio = _apri(data);

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
