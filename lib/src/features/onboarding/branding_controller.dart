import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/errors/api_exception.dart';
import '../../core/providers.dart';
import '../../core/storage/local_cache.dart';
import 'data/gym_branding.dart';

/// Lo stato dell'onboarding white-label — A2.1 / A2.2 / A2.5.
class BrandingState {
  const BrandingState({required this.branding, this.joinCode, this.isLoading = false});

  final GymBranding branding;
  final String? joinCode;
  final bool isLoading;

  /// `true` quando l'utente ha già scelto una palestra.
  bool get hasGym => joinCode != null && joinCode!.isNotEmpty;
}

/// Il branding della palestra: dalla cache subito, dalla rete dopo.
///
/// 🚨 **L'ordine è quello e non l'inverso.** Al secondo avvio l'app si apre già
/// vestita dei colori giusti, e la richiesta di rete aggiorna in sottofondo. Un
/// avvio che aspetta la rete per decidere di che colore essere mostra mezzo
/// secondo di bianco a ogni apertura, ed è la prima cosa che si nota di un'app
/// white-label — proprio la cosa che deve funzionare bene.
class BrandingController extends StateNotifier<BrandingState> {
  BrandingController(this._api, this._cache)
    : super(
        BrandingState(
          // Avvio a caldo: se c'è una cache, si parte da lì.
          branding: _cache.branding != null
              ? GymBranding.fromJson(_cache.branding!)
              : GymBranding.neutral,
          joinCode: _cache.joinCode,
        ),
      );

  final ApiClient _api;
  final LocalCache _cache;

  /// 🆕 **Si prosegue senza palestra** — F3.
  ///
  /// Non chiama la rete: non c'è niente da cercare. Azzera il codice e riporta
  /// il branding a quello neutro, che è **esattamente** ciò che il server
  /// risponderà poi per un tenant personale.
  ///
  /// ⚠️ **Il codice va tolto dalla cache, non solo dallo stato.** Se restasse su
  /// disco, il prossimo avvio ripartirebbe con la palestra di prima — e la
  /// persona si troverebbe a fare l'accesso dentro una palestra che ha appena
  /// deciso di non avere.
  Future<void> senzaPalestra() async {
    await _cache.forgetGym();

    state = const BrandingState(branding: GymBranding.neutral);
  }

  /// Cerca la palestra da un codice d'invito.
  ///
  /// Lancia `NotFoundException` se il codice non esiste **o** se la palestra è
  /// sospesa: il backend risponde allo stesso modo di proposito, per non far
  /// diventare questo endpoint un modo per enumerare i clienti. L'app quindi
  /// mostra un solo messaggio, e va bene così.
  Future<GymBranding> lookup(String code) async {
    final normalizzato = code.trim().toUpperCase();

    state = BrandingState(branding: state.branding, joinCode: state.joinCode, isLoading: true);

    try {
      final data = await _api.get<Map<String, dynamic>>(
        '/branding/lookup',
        query: {'code': normalizzato},
      );

      final branding = GymBranding.fromJson(data);

      await _cache.setBranding(data);
      await _cache.setJoinCode(normalizzato);

      state = BrandingState(branding: branding, joinCode: normalizzato);

      return branding;
    } finally {
      if (state.isLoading) {
        state = BrandingState(branding: state.branding, joinCode: state.joinCode);
      }
    }
  }

  /// Riallinea il branding all'avvio, **senza far fallire niente**.
  ///
  /// Se la palestra ha cambiato colori si aggiorna; se il telefono è offline si
  /// tiene quello in cache. Un errore qui non deve impedire l'avvio: i colori
  /// sbagliati sono un problema estetico, un'app che non parte no.
  Future<void> refreshQuietly() async {
    final code = state.joinCode;

    if (code == null || code.isEmpty) return;

    try {
      final data = await _api.get<Map<String, dynamic>>(
        '/branding/lookup',
        query: {'code': code},
      );

      await _cache.setBranding(data);

      state = BrandingState(branding: GymBranding.fromJson(data), joinCode: code);
    } on Object catch (error) {
      final tradotto = ApiClient.unwrapError(error);

      // 🚨 Un 404 qui non è un problema di rete: vuol dire che la palestra è
      // stata sospesa o cancellata. Si tiene comunque il branding in cache —
      // chi ha già un account deve poter arrivare alla schermata che gli spiega
      // cosa è successo, non a una schermata neutra che sembra un'altra app.
      if (tradotto is NetworkException || tradotto is NotFoundException) return;
    }
  }

  /// Dimentica la palestra: si usa al «cambia palestra», non al logout.
  Future<void> forget() async {
    await _cache.forgetGym();

    state = const BrandingState(branding: GymBranding.neutral);
  }
}

final brandingControllerProvider = StateNotifierProvider<BrandingController, BrandingState>(
  (ref) => BrandingController(ref.watch(apiClientProvider), ref.watch(localCacheProvider)),
);
