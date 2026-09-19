/// 📱 **Il profilo, calcolato sul telefono** — 19/09/2026.
///
/// 📌 Il committente: *«assicurati che non ci scriva niente di personale
/// (esattamente come peso altezza e data di nascita)»*.
///
/// ══ 💡 LA STESSA FORMA DEL SERVER, APPOSTA ═══════════════════════════════
///
/// Fino al 19/09 il profilo arrivava da `GET /profile`, con dentro `missing`,
/// gli orari dei pasti completi e le etichette di livelli e obiettivi. 🚨 Qui
/// si ricostruisce **lo stesso JSON**, così `UserProfile.fromJson` — e ogni
/// schermata che lo usa — non si accorge che il server non c'è più.
///
/// ⚠️ **Le etichette e gli orari sono copiati dal server**
/// (`Profile::ACTIVITY_LEVELS`, `Profile::GOALS`, `MealType::DEFAULT_HOURS`):
/// se cambiano là, vanno cambiati qui. Il server li tiene per il pannello dei
/// trainer, che compone **modelli** di piano su valori d'esempio.
library;

/// I livelli di attività, con l'etichetta — `Profile::ACTIVITY_LEVELS`.
const livelliDiAttivita = <String, String>{
  'sedentary': 'Sedentario (lavoro da fermo, niente allenamenti)',
  'light': 'Leggermente attivo (1-2 allenamenti a settimana)',
  'moderate': 'Moderatamente attivo (3-4 a settimana)',
  'active': 'Molto attivo (5-6 a settimana)',
  'very_active': 'Estremamente attivo (ogni giorno, o due sedute)',
};

/// Gli obiettivi, con l'etichetta — `Profile::GOALS`.
const obiettivi = <String, String>{
  'lose_fast': 'Dimagrimento rapido',
  'lose_slow': 'Dimagrimento graduale',
  'maintain': 'Mantenimento',
  'gain_lean': 'Aumento massa controllato',
  'gain_fast': 'Aumento massa rapido',
};

/// Gli orari di serie dei sei pasti — `MealType::DEFAULT_HOURS`.
const orariDiSerie = <String, String>{
  'breakfast': '07:00',
  'morning_snack': '10:30',
  'lunch': '13:00',
  'afternoon_snack': '16:30',
  'dinner': '20:00',
  'evening_snack': '22:30',
};

/// Il profilo salvato sul telefono, nella forma che rispondeva il server.
///
/// ⚠️ `weight_kg` resta `null` e sta **sempre** in `missing`, e `derived` resta
/// `null`: è il contratto di prima (S5.5). Il peso sta nell'archivio del corpo,
/// e il fabbisogno lo calcola `targetLocaleProvider`.
Map<String, dynamic> profiloComeLoMandavaIlServer(
  Map<String, dynamic> dati, {
  DateTime? oggi,
}) {
  final nascita = DateTime.tryParse(dati['birthdate']?.toString() ?? '');
  final adesso = oggi ?? DateTime.now();

  int? eta;
  if (nascita != null) {
    eta = adesso.year - nascita.year;
    if (adesso.month < nascita.month ||
        (adesso.month == nascita.month && adesso.day < nascita.day)) {
      eta--;
    }
  }

  /*
   * 💡 Sempre i sei pasti, con quelli scelti sopra quelli di serie — e solo
   * chiavi conosciute: è la stessa regola di `ProfileController::orariCompleti`.
   */
  final scelti = (dati['meal_hours'] as Map?)?.cast<String, dynamic>() ?? {};
  final orari = {
    for (final o in orariDiSerie.entries)
      o.key: scelti[o.key]?.toString() ?? o.value,
  };

  return {
    'sex': dati['sex'],
    'birthdate': dati['birthdate'],
    'age': eta,
    'height_cm': dati['height_cm'],
    'activity_level': dati['activity_level'],
    'goal': dati['goal'],
    'target_weight_kg': dati['target_weight_kg'],
    'meal_hours': orari,
    'weight_kg': null,
    'derived': null,
    'missing': [
      'weight_kg',
      if (dati['sex'] == null) 'sex',
      if (dati['birthdate'] == null) 'birthdate',
      if (dati['height_cm'] == null) 'height_cm',
    ],
    'options': {'activity_levels': livelliDiAttivita, 'goals': obiettivi},
  };
}
