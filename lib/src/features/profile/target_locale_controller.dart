import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../health/health_controller.dart';
import 'corpo_controller.dart';
import 'data/calcolatore_calorie.dart';
import 'profile_controller.dart';

/// Il fabbisogno calorico, **calcolato sul telefono** — S5.1 / correzione S7.
///
/// ── 🚨 Perché questo file è dovuto nascere ────────────────────────────────
///
/// In S5 il peso è uscito dal server, e `Profile::computedTargets()` ha smesso
/// di poter calcolare: senza peso non c'è BMR, senza BMR non c'è TDEE, senza
/// TDEE non c'è nessun obiettivo. Il commento nel backend diceva già la cosa
/// giusta — *«chi chiede i target di una persona vera li calcola nell'app»* —
/// ⚠️ **ma nell'app non li calcolava nessuno.**
///
/// Il risultato lo ha visto il committente provandola: profilo compilato, peso
/// registrato, e la schermata principale che continuava a dire *«Nessun
/// obiettivo impostato — compila i tuoi dati»*. Cioè l'app chiedeva dei dati
/// che erano già stati inseriti, e non li usava.
///
/// 💡 **Il calcolo c'era già**: `CalcolatoreCalorie` è il ritratto fedele di
/// `CalorieCalculator`, portato in Dart in S5.1 con i suoi tredici test.
/// Mancava solo qualcuno che gli passasse i due pezzi — il profilo dal server,
/// il peso dall'archivio locale.

/// Quello che l'app riesce a calcolare da sola.
class TargetLocale {
  const TargetLocale({
    required this.kcal,
    required this.macro,
    required this.bmr,
    required this.tdee,
  });

  final int kcal;
  final Macro macro;
  final double bmr;
  final double tdee;
}

/// `null` quando manca un pezzo, e **non si inventa niente**.
///
/// 🚨 Servono tutti e quattro: sesso, data di nascita, altezza e **peso**. Senza
/// uno solo, Mifflin-St Jeor non si applica — e un obiettivo calorico
/// inventato non è un numero storto, è **una dieta storta**. È la stessa regola
/// che il backend applicava restituendo `null`.
///
/// ⚠️ Il peso arriva dall'**archivio locale**, non dal server: dopo S5 il server
/// non ce l'ha, e chiederglielo restituirebbe sempre niente.
final targetLocaleProvider = FutureProvider.autoDispose<TargetLocale?>((ref) async {
  final profilo = await ref.watch(profileProvider.future);
  final pesata = await ref.watch(archivioSaluteProvider).ultimoPeso();

  // Si rilegge quando l'utente si pesa: senza, l'obiettivo resterebbe quello di
  // stamattina fino al riavvio dell'app.
  ref.watch(revisioneCorpoProvider);

  final kg = pesata?.pesoKg;
  final cm = profilo.heightCm?.toDouble();
  final nascita = profilo.birthdate;
  final sesso = profilo.sex;

  if (kg == null || cm == null || nascita == null || sesso == null) return null;

  const calcolatore = CalcolatoreCalorie();

  final bmr = calcolatore.bmr(
    kg: kg,
    cm: cm,
    eta: calcolatore.etaDa(nascita),
    sesso: sesso,
  );

  final tdee = calcolatore.tdee(bmr, profilo.activityLevel ?? 'sedentary');
  final kcal = calcolatore.targetCalorico(tdee, profilo.goal ?? 'maintain');

  return TargetLocale(
    kcal: kcal,
    macro: calcolatore.macro(kcal, profilo.goal ?? 'maintain'),
    bmr: bmr,
    tdee: tdee,
  );
});
