import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../auth/auth_controller.dart';
import 'data/profile_models.dart';

/// Il profilo dell'iscritto — C8.
final profileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final data = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/profile');

  return UserProfile.fromJson(data);
});

/// Lo storico del peso, per il grafico e per l'ultima pesata.
final weightHistoryProvider = FutureProvider.autoDispose<List<WeightEntry>>((ref) async {
  final data = await ref.watch(apiClientProvider).get<List<dynamic>>('/body-metrics');

  return data
      .map((e) => WeightEntry.fromJson((e as Map).cast<String, dynamic>()))
      .where((e) => true)
      .toList();
});

class ProfileActions {
  ProfileActions(this._ref);

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  /// Salva **solo i campi passati**.
  ///
  /// 🚨 È una PATCH, e i parametri assenti non finiscono nel corpo: mandare
  /// `null` per un campo non toccato lo **azzererebbe** sul server. È la
  /// differenza fra «non l'ho cambiato» e «l'ho svuotato», e in una schermata
  /// che salva un campo alla volta è la differenza fra funzionare e perdere i
  /// dati a ogni salvataggio.
  Future<void> save({
    String? sex,
    DateTime? birthdate,
    int? heightCm,
    String? activityLevel,
    String? goal,
    double? targetWeightKg,
    Map<String, String>? mealHours,
  }) async {
    final corpo = <String, dynamic>{
      'sex': ?sex,
      'birthdate': ?birthdate == null ? null : DateFormat('yyyy-MM-dd').format(birthdate),
      'height_cm': ?heightCm,
      'activity_level': ?activityLevel,
      'goal': ?goal,
      'target_weight_kg': ?targetWeightKg,
      'meal_hours': ?mealHours,
    };

    if (corpo.isEmpty) return;

    await _api.patch<dynamic>('/profile', body: corpo);

    _invalida();
  }

  /// Registra il peso del giorno.
  ///
  /// ⚠️ Il backend fa un UPSERT su `(utente, data)`: pesarsi due volte lo stesso
  /// giorno è una **correzione**, non un secondo punto sul grafico. È il
  /// comportamento giusto — la bilancia si guarda spesso due volte di seguito.
  Future<void> logWeight({required double kg, DateTime? date, double? bodyFatPct}) async {
    await _api.post<dynamic>(
      '/body-metrics',
      body: {
        'weight_kg': kg,
        'date': DateFormat('yyyy-MM-dd').format(date ?? DateTime.now()),
        'body_fat_pct': ?bodyFatPct,
      },
    );

    _invalida();
  }

  /// Cambia la propria email — G8.
  ///
  /// 🚨 Serve la password attuale: cambiare l'email è come cambiare le chiavi,
  /// perché è con quella che si recupera l'accesso.
  Future<void> cambiaEmail({required String email, required String passwordAttuale}) async {
    await _api.patch<dynamic>(
      '/account/email',
      body: {'email': email, 'current_password': passwordAttuale},
    );

    // L'utente in memoria ha ancora l'indirizzo vecchio: senza questo, il
    // profilo continuerebbe a mostrarlo finché non si riavvia l'app.
    await _ref.read(authControllerProvider.notifier).refresh();
  }

  /// Cambia la propria password — G8.
  ///
  /// ⚠️ Il server chiude **le altre sessioni**: chi la cambia spesso teme che
  /// qualcuno sia entrato, e lasciare attivi gli altri token vorrebbe dire non
  /// aver cambiato niente per chi è già dentro.
  Future<void> cambiaPassword({
    required String passwordAttuale,
    required String nuova,
    required String conferma,
  }) async {
    await _api.patch<dynamic>(
      '/account/password',
      body: {
        'current_password': passwordAttuale,
        'password': nuova,
        'password_confirmation': conferma,
      },
    );
  }

  /// Cosa succede eliminando l'account, **detto dal server** — C6.
  Future<Map<String, dynamic>> deletionPreview() =>
      _api.get<Map<String, dynamic>>('/account/deletion-preview');

  /// Elimina l'account. Dopo, la sessione non esiste più.
  Future<void> deleteAccount(String password) async {
    await _api.delete('/account', body: {'password': password});

    // Il token non vale più niente: si esce subito, senza aspettare un 401 su
    // una schermata a caso.
    await _ref.read(authControllerProvider.notifier).forgetSession();
  }

  /// 🚨 Il peso entra nel fabbisogno, il fabbisogno entra nel diario.
  ///
  /// Invalidare solo il profilo lascerebbe il diario a mostrare il target
  /// vecchio finché non lo si riapre — e la persona vedrebbe due numeri
  /// diversi nella stessa app, senza sapere quale credere.
  void _invalida() {
    _ref.invalidate(profileProvider);
    _ref.invalidate(weightHistoryProvider);
  }
}

final profileActionsProvider = Provider<ProfileActions>(ProfileActions.new);
