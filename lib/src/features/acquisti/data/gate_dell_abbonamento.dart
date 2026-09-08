import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../training/data/limiti_delle_schede.dart';

/// 🔒 Se questa persona è dentro il gate dell'abbonamento — 08/09/2026.
///
/// ══ 🚨 UNA PORTA SOLA, E QUESTA È QUELLA ═══════════════════════════════════
///
/// ⛔ **Prima del 08/09 ogni funzione se lo ricalcolava**: `progressione_
/// controller`, `settimana_controller` e `schermata_tu` scrivevano tutti e tre
/// `soloSeAbbonato(ref.watch(authControllerProvider).user?.abbonato)`.
///
/// 🚨 Tre stesure della stessa condizione, e in questo progetto la terza è già
/// stata sbagliata una volta — il 27/08, quando `senzaLimiti` era stata riusata
/// al posto di `soloSeAbbonato` e apriva il gate a chi aveva l'AI illimitata
/// senza abbonamento. 💡 Con il gate che si allarga a cinque card e a un limite
/// sugli allenamenti, la quarta e la quinta stesura non si scrivono.
///
/// ⚠️ **`null` è abbonato**, come in [soloSeAbbonato]: il profilo può non essere
/// ancora arrivato, e un flag che manca non deve chiudere fuori chi ha pagato.
/// ⛔ Il server rifiuta comunque quello che va rifiutato — questo cancello
/// decide **cosa mostrare**, non cosa concedere.
final abbonatoProvider = Provider<bool>(
  (ref) => soloSeAbbonato(ref.watch(authControllerProvider).user?.abbonato),
);

/// 🏋️ Quanti allenamenti al giorno può far partire chi non è abbonato.
///
/// 📌 Il committente, 08/09/2026: *«un utente non abbonato può far partire
/// dall'app un solo allenamento al giorno»*.
///
/// ══ 🚨 «FAR PARTIRE», NON «AVERE» ═════════════════════════════════════════
///
/// ⛔ **Il limite conta le sedute aperte dall'app, e nient'altro.** Quello che
/// arriva dall'orologio non lo tocca: sono allenamenti che la persona ha
/// **già fatto**, e nasconderglieli sarebbe togliere un dato suo per venderglielo
/// indietro.
///
/// 💡 E non blocca chi **riprende** una seduta rimasta aperta: quella è partita
/// ieri, e riprenderla non è farne una nuova.
const allenamentiAlGiornoSenzaAbbonamento = 1;
