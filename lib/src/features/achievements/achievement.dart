/// Gli achievements — 3b-A.8, 24/08/2026.
///
/// ══ ⏳ QUESTO FILE È UN POSTO VUOTO, DI PROPOSITO ══════════════════════════
///
/// 📌 Il committente: *«bisogna sviluppare un sistema di achievements. facci
/// una fase a parte nel piano»* · *«un carosello di cards per gli achievements
/// [...] (finché non esistono gli achievements è nascosta, ma tu **preparala**)»*.
///
/// 🚨 **Non c'è nessuna regola che assegni una medaglia**, e non deve esserci:
/// quello è **FASE 12**, e le cinque domande di disegno che la aprono non sono
/// state ancora decise. ⛔ Inventarle qui vorrebbe dire eseguire un piano che
/// nessuno ha scritto — e poi doverle disfare.
///
/// 💡 Quello che c'è è la **forma**: il modello, l'ambito, e un provider che
/// oggi torna sempre l'elenco vuoto. Il giorno che FASE 12 arriva, si cambia il
/// provider e le tre schermate si accendono da sole.
///
/// ⚠️ **E finché è vuoto non si vede niente** — vedi `CaroselloAchievements`.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Di cosa parla una medaglia.
///
/// 🚨 Serve perché le tre schermate ne mostrano **insiemi diversi**: «Oggi» le
/// vuole tutte, lo Storico solo quelle dell'allenamento, il Diario solo quelle
/// dell'alimentazione. ⛔ Senza un ambito, ogni schermata dovrebbe filtrare per
/// titolo — cioè indovinare.
enum AmbitoAchievement {
  allenamento,
  alimentazione,

  /// 💡 Quelle che non sono né una cosa né l'altra: costanza, primi passi,
  /// anniversari. Compaiono solo dove si mostrano **tutte**.
  generale,
}

@immutable
class Achievement {
  const Achievement({
    required this.codice,
    required this.titolo,
    required this.descrizione,
    required this.icona,
    required this.ambito,
    this.ottenutoIl,
  });

  /// L'identificativo stabile, che un domani arriverà dal server.
  final String codice;

  final String titolo;
  final String descrizione;
  final IconData icona;
  final AmbitoAchievement ambito;

  /// Quando è stato ottenuto. `null` = non ancora.
  ///
  /// ⚠️ Il campo esiste già perché la domanda «si mostrano anche quelli non
  /// ancora presi?» è una delle cinque di FASE 12: tenerlo adesso costa niente,
  /// aggiungerlo dopo vorrebbe dire toccare tre schermate.
  final DateTime? ottenutoIl;
}

/// Le medaglie di una persona.
///
/// ⏳ **Torna sempre vuoto finché FASE 12 non esiste.** Non è un segnaposto da
/// riempire a caso: è il punto in cui si innesterà la sorgente vera, e nel
/// frattempo dice la verità — di medaglie non ce ne sono.
final achievementsProvider = Provider<List<Achievement>>((ref) => const []);

/// Quelle di un ambito, più le generali quando si chiede tutto.
final achievementsPerAmbitoProvider =
    Provider.family<List<Achievement>, AmbitoAchievement?>((ref, ambito) {
      final tutti = ref.watch(achievementsProvider);

      if (ambito == null) return tutti;

      return tutti.where((a) => a.ambito == ambito).toList(growable: false);
    });
