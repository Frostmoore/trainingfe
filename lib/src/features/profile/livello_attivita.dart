import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../health/health_controller.dart';
import 'data/modello_calorie.dart';
import 'profile_controller.dart';

/// Il livello di attività, **sul telefono** — 3b-G.1/G.2, 26/08/2026.
///
/// ══ 📌 PERCHE' NON STA PIU' SUL SERVER ════════════════════════════════════
///
/// Il committente: *«Non vedo perché il livello di attività dovrebbe risiedere
/// sul server, può tranquillamente stare sul telefono, tanto i calcoli li
/// facciamo lì, come il peso»*.
///
/// 💡 È la stessa decisione di **D9-bis**: dopo S5 il peso è uscito dal server
/// perché il fabbisogno si calcola qui. ⚠️ Il livello di attività è **un
/// ingresso dello stesso calcolo** — tenerlo di là voleva dire che per
/// cambiare un'etichetta serviva un deploy, e che un dato che dice il mestiere
/// di una persona viaggiava senza motivo.
///
/// ══ 💾 E FINISCE NEL BACKUP DA SOLO ═══════════════════════════════════════
///
/// 🚨 `LocalCache` è `SharedPreferences`, e `PreferenzeNelBackup.esporta()` le
/// **enumera tutte**: questa chiave viaggia con la copia di sicurezza senza che
/// nessuno la aggiunga a un elenco. ⚠️ È anche il motivo per cui il valore
/// salvato è la **chiave** (`desk`) e non l'etichetta: le etichette cambiano, e
/// un backup ripristinato fra un anno deve continuare a voler dire la stessa
/// cosa.
class LivelloAttivitaScelto extends Notifier<String?> {
  static const chiave = 'obiettivo.livello_attivita';

  /// ⛔ **Nessun ripiego, e qui è tutto il punto della 3b-G.** `null` vuol dire
  /// «non ha ancora scelto», che è uno stato vero e diverso da «è sedentario».
  /// 🚨 Il ripiego naturale sarebbe `?? 'sedentary'`: darebbe a tutti un
  /// fabbisogno plausibile e sbagliato, senza errori da nessuna parte.
  @override
  String? build() => ref.watch(localCacheProvider).getString(chiave);

  Future<void> scegliLivello(String livello) async {
    state = livello;

    await ref.read(localCacheProvider).setString(chiave, livello);
  }
}

final livelloAttivitaSceltoProvider =
    NotifierProvider<LivelloAttivitaScelto, String?>(LivelloAttivitaScelto.new);

/// Il livello **in uso**: la scelta di adesso, o quello che c'era prima.
///
/// ══ ⚠️ L'EREDITA' DAL SERVER, E PERCHE' NON SI CONVERTE ═══════════════════
///
/// I profili di prima hanno un livello salvato sul server (`moderate`, …).
/// ⛔ **Non si può convertirlo in automatico**: chi ha scelto «moderato (3-4
/// allenamenti)» ha dichiarato lo **sport**, e del suo **lavoro** non sappiamo
/// niente. Mapparlo su un gradino del modello misurato vuol dire inventargli un
/// mestiere.
///
/// 💡 Quindi il vecchio valore **continua a valere finché non risponde**, e la
/// domanda gliela fa la schermata del profilo. 🚨 Un obiettivo che cambia da
/// solo prima che qualcuno abbia risposto è peggio di un obiettivo vecchio.
final livelloAttivitaProvider = Provider.autoDispose<String?>((ref) {
  final scelto = ref.watch(livelloAttivitaSceltoProvider);

  if (scelto != null) return scelto;

  return ref.watch(profileProvider).valueOrNull?.activityLevel;
});

/// Il modello in uso, `null` se il livello non è di nessuno dei due.
final modelloCalorieProvider = Provider.autoDispose<ModelloCalorie?>(
  (ref) => modelloDelLivello(ref.watch(livelloAttivitaProvider)),
);

/// I passi al giorno dell'ultimo mese — 3b-G.1.4.
///
/// 💡 `autoDispose`: si legge quando si apre la pagina della scelta e non serve
/// tenerlo in memoria per il resto della vita dell'app.
///
/// ⚠️ `null` vuol dire «non lo so», e la pagina in quel caso **non suggerisce
/// niente** invece di suggerire il gradino più basso: un suggerimento inventato
/// su una dieta è peggio di nessun suggerimento.
final passiAlGiornoProvider = FutureProvider.autoDispose<int?>(
  (ref) => ref.watch(ponteSaluteProvider).passiAlGiorno(),
);

/// Se alla persona la domanda non è ancora stata fatta.
///
/// 💡 Guarda **la scelta locale**, non il livello in uso: chi ha ereditato un
/// livello dal server ce l'ha, ma non ha ancora deciso con quale modello vuole
/// che l'app conti — che è la domanda nuova.
final deveScegliereIlModelloProvider = Provider<bool>(
  (ref) => ref.watch(livelloAttivitaSceltoProvider) == null,
);
