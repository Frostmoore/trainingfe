import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/import/data/bozza_in_modulo.dart';

/// 📄 **La bozza vera, quella tornata dal server il 20/09/2026.**
///
/// 🚨 Non un esempio scritto a mano: è il JSON che il modello ha restituito per
/// `test_scheda.pdf` nel giro K7.3. I test con dati inventati dicono che il
/// codice regge **quello che immaginiamo**, non quello che arriva.
void main() {
  const grezza = r'''
{"name":"Scheda Palestra 3 Giorni - Demo/Test","notes":null,"confidence":0.95,
 "day_names":["Giorno 1 - Spinta + quadricipiti","Giorno 2 - Trazione + catena posteriore","Giorno 3 - Full body tecnico"],
 "giorni":3,
 "exercises":[
  {"name":"Squat guidato o back squat","sets":4,"reps":"6-8","rest_sec":120,"target_weight":null,"notes":"Tecnica pulita.","muscle_group":null,"secondary_muscles":[],"confidence":0.95,"day":1},
  {"name":"Panca piana","sets":4,"reps":"6-8","rest_sec":120,"target_weight":null,"notes":null,"muscle_group":null,"secondary_muscles":[],"confidence":0.95,"day":1},
  {"name":"Stacco rumeno","sets":4,"reps":"6-8","rest_sec":120,"target_weight":null,"notes":null,"muscle_group":null,"secondary_muscles":[],"confidence":0.9,"day":2},
  {"name":"Plank","sets":3,"reps":"30-45 sec","rest_sec":45,"target_weight":null,"notes":null,"muscle_group":null,"secondary_muscles":[],"confidence":0.9,"day":3}
 ]}
''';

  test('la bozza vera diventa una scheda con i suoi giorni e i suoi esercizi', () {
    final scheda = schedaDallaBozza(
      json.decode(grezza) as Map<String, dynamic>,
    );

    expect(scheda.nome, 'Scheda Palestra 3 Giorni - Demo/Test');
    expect(scheda.giorni, hasLength(3));
    expect(scheda.giorni[0].nome, 'Giorno 1 - Spinta + quadricipiti');
    expect(scheda.giorni[0].esercizi, hasLength(2));
    expect(scheda.giorni[2].esercizi.single.nome, 'Plank');

    // ⚠️ `reps` non è sempre un numero: «30-45 sec» deve sopravvivere.
    expect(scheda.giorni[2].esercizi.single.ripetizioni, '30-45 sec');
  });
}
