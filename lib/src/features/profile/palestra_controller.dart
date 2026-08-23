import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../onboarding/branding_controller.dart';

/// I dettagli della palestra a cui si è iscritti — 3b-P.13, 23/08/2026.
///
/// ⛔ **Non duplica il branding.** `GymBranding` ha insegna, logo e colori
/// perché servono a *vestire* l'app, e arrivano da un endpoint pubblico. Qui c'è
/// quello che si può dire solo a chi è dentro: il contatto e da quando ne fa
/// parte.
class DettagliPalestra {
  const DettagliPalestra({
    required this.nome,
    this.logoUrl,
    this.contatto,
    this.iscrittoDal,
  });

  factory DettagliPalestra.fromJson(Map<String, dynamic> j) => DettagliPalestra(
    nome: j['name']?.toString() ?? '',
    logoUrl: j['logo_url']?.toString(),
    contatto: j['contact_email']?.toString(),
    iscrittoDal: DateTime.tryParse(j['iscritto_dal']?.toString() ?? ''),
  );

  final String nome;
  final String? logoUrl;
  final String? contatto;
  final DateTime? iscrittoDal;
}

/// 💡 `null` non è un errore: è «non sei iscritto a nessuna palestra».
final dettagliPalestraProvider = FutureProvider.autoDispose<DettagliPalestra?>((
  ref,
) async {
  final risposta = await ref
      .read(apiClientProvider)
      .get<Map<String, dynamic>>('/account/gym');

  final dati = risposta['data'];

  return dati is Map<String, dynamic> ? DettagliPalestra.fromJson(dati) : null;
});

/// Esce dalla palestra — 3b-P.13.3.
///
/// ══ 🚨 DOPO, L'APP DEVE CAMBIARE FACCIA ═══════════════════════════════════
///
/// ⚠️ Il branding è in cache (`LocalCache`), e senza invalidarlo l'app
/// continuerebbe a mostrare insegna e colori di una palestra da cui si è appena
/// usciti — finché non si riavvia. 🚨 Sarebbe il modo più diretto di far
/// credere che l'operazione non abbia funzionato.
///
/// 💡 Il server risponde già con il branding nuovo, proprio per questo: è la
/// stessa scelta fatta per `join-gym`.
final esciDallaPalestraProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>('/account/leave-gym');

    await ref.read(brandingControllerProvider.notifier).refreshQuietly();

    ref.invalidate(dettagliPalestraProvider);
  };
});
