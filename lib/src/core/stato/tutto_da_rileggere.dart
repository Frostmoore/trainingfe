import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/diary/data/diario_locale.dart';
import '../../features/health/health_controller.dart';
import '../../features/profile/corpo_controller.dart';
import '../../features/profile/profile_controller.dart';
import '../../features/progress/progress_controller.dart';
import '../../features/training/percorso_controller.dart';
import '../../features/training/progressione_controller.dart';
import '../../features/training/settimana_controller.dart';
import '../../features/training/training_controller.dart';

/// Dice a tutta l'app che quello che aveva letto **non vale più**.
///
/// ══ 🚨 A COSA SERVE, E IL GUASTO CHE L'HA FATTA NASCERE ═══════════════════
///
/// ⛔ 23/09/2026, giro UX: entrato come **un'altra persona** sullo stesso
/// telefono, la schermata «Oggi» del nuovo arrivato mostrava **8 kcal bruciate
/// e 363% di carico** — i numeri di chi c'era prima.
///
/// 🚨 E l'archivio era **già stato svuotato**: il database sul disco era vuoto,
/// controllato riga per riga. Quello che restava era il **ricordo** dei
/// provider, che avevano già letto e non avevano motivo di rileggere.
///
/// ⚠️ È la stessa famiglia del difetto dei consensi (§161.3): uno stato in
/// cache che sopravvive a un cambio di sessione. Qui però quello che
/// sopravvive sono **i dati di un'altra persona, sotto gli occhi di chi è
/// appena entrato** — cioè esattamente quello che `ArchivioSalute.svuota()`
/// esiste per impedire. Cancellare le righe e lasciare lo schermo com'era
/// risolve il problema del disco e non quello della persona.
///
/// ══ ⚠️ PERCHÉ UN ELENCO, E PERCHÉ NON PUÒ MARCIRE ════════════════════════
///
/// 💡 Questi segnali sono `StateProvider<int>`: non c'è modo di enumerarli
/// dall'interno come si fa con `allTables`. L'elenco a mano qui è **obbligato**,
/// e un elenco a mano che deve contenere tutto in questo progetto si è già
/// rotto tre volte (`svuota()` due, le preferenze del backup una).
///
/// 🚨 Per questo esiste `test/tutto_da_rileggere_test.dart`: legge i sorgenti,
/// trova ogni `revisione…Provider` dichiarato in `lib/` e pretende che compaia
/// qui. Un segnale nuovo che nessuno aggiunge fa diventare rosso il test il
/// giorno stesso in cui nasce.
void tuttoDaRileggere(Ref ref) {
  for (final segnale in <StateProvider<int>>[
    revisioneDiarioProvider,
    revisioneAllenamentiProvider,
    revisioneCorpoProvider,
    revisioneDelProfiloProvider,
    revisioneFotoProvider,
    revisioneDeiPercorsiProvider,
    revisioneDellAnalisiProvider,
    revisioneDellaSettimanaProvider,
    revisioneSchedeProvider,
  ]) {
    ref.read(segnale.notifier).state++;
  }
}
