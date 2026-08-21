import 'package:flutter/material.dart';

/// Gli orari dei sei pasti — C8.
///
/// 🚨 **Non è decorazione.** Fino alla fase C `meal_hours` era una colonna che
/// si salvava e non veniva letta da nessuno; ora determina davvero in quale
/// pasto finisce un cibo. Chi cena alle 18:30 vuole che uno spuntino delle 19
/// risulti cena, non merenda.
class MealHoursEditor extends StatelessWidget {
  const MealHoursEditor({
    required this.orari,
    required this.onChanged,
    super.key,
  });

  final Map<String, String> orari;
  final ValueChanged<Map<String, String>> onChanged;

  /// L'ordine è quello della giornata, non quello alfabetico né quello con cui
  /// arrivano le chiavi.
  static const _ordine = [
    ('breakfast', 'Colazione'),
    ('morning_snack', 'Spuntino del mattino'),
    ('lunch', 'Pranzo'),
    ('afternoon_snack', 'Merenda'),
    ('dinner', 'Cena'),
    ('evening_snack', 'Spuntino serale'),
  ];

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        for (final (chiave, etichetta) in _ordine)
          ListTile(
            dense: true,
            title: Text(etichetta),
            trailing: TextButton(
              onPressed: () => _scegli(context, chiave),
              child: Text(
                orari[chiave] ?? '—',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> _scegli(BuildContext context, String chiave) async {
    final attuale = _parse(orari[chiave]);

    final scelta = await showTimePicker(
      context: context,
      initialTime: attuale ?? const TimeOfDay(hour: 12, minute: 0),
      // Sempre l'orologio a 24 ore: `HH:MM` è il formato che il server valida,
      // e un AM/PM mal letto sposterebbe un pasto di dodici ore.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (scelta == null) return;

    final aggiornati = Map.of(orari)
      ..[chiave] =
          '${scelta.hour.toString().padLeft(2, '0')}:${scelta.minute.toString().padLeft(2, '0')}';

    onChanged(aggiornati);
  }

  static TimeOfDay? _parse(String? hhmm) {
    if (hhmm == null) return null;

    final parti = hhmm.split(':');

    if (parti.length != 2) return null;

    final h = int.tryParse(parti[0]);
    final m = int.tryParse(parti[1]);

    if (h == null || m == null) return null;

    return TimeOfDay(hour: h, minute: m);
  }
}
