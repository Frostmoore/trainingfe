import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/training/data/session_models.dart';

/// Una seduta letta dall'archivio locale — FASE 11.4, 21/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// Da qui in poi le calorie di un allenamento **le calcola il telefono**. Le
/// due regole che il server applicava e che è facile perdere nel trasloco:
///
/// | | |
/// |---|---|
/// | **quello scritto vince** | una correzione a mano non si sovrascrive mai |
/// | **una seduta aperta non ha un numero** | la formula darebbe le calorie «finora» |
///
/// ⚠️ La seconda non è ovvia: senza, chi guarda il player a metà allenamento
/// vedrebbe un numero che **cambia mentre lo legge**, e non è una stima — è un
/// conteggio parziale spacciato per totale.
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  Future<WorkoutSession> leggi(int id, {double kg = 80}) async {
    final seduta = (await archivio.sedute()).firstWhere((s) => s.id == id);

    return WorkoutSession.dallArchivio(
      seduta,
      await archivio.serieDi(id),
      kg: kg,
    );
  }

  Future<void> serie(int seduta, {double? met}) => archivio.registraSerie(
    SerieDelleSeduteCompanion.insert(
      sedutaId: seduta,
      esercizioId: 1,
      nomeEsercizio: 'Squat',
      met: Value(met),
      numero: 1,
      ripetizioni: const Value(10),
      pesoKg: const Value(60),
    ),
  );

  test('⛔ una seduta APERTA non mostra calorie stimate', () async {
    final id = await archivio.apriSeduta(
      quando: DateTime.now().subtract(const Duration(minutes: 30)),
    );
    await serie(id, met: 6);

    final s = await leggi(id);

    expect(s.isOpen, isTrue);
    // 🚨 `null`, non «le calorie finora»: quel numero cambierebbe mentre lo si
    // guarda, e si leggerebbe come un totale.
    expect(s.kcal, isNull);
  });

  test('chiusa, il numero esce dalla formula trasportata', () async {
    final inizio = DateTime(2026, 8, 20, 18);
    final id = await archivio.apriSeduta(quando: inizio);
    await serie(id, met: 6);
    await archivio.chiudiSeduta(id, quando: inizio.add(const Duration(hours: 1)));

    // 💡 Qui `chiudiSeduta` non ha scritto kcal: il calcolo lo fa la lettura.
    // MET 6.0 × 80 kg × 1 h = 480.
    final s = await leggi(id);

    expect(s.isOpen, isFalse);
    expect(s.kcal, 480);
    expect(s.kcalSource, 'formula');
  });

  test('senza MET vince il ripiego, non lo zero', () async {
    final inizio = DateTime(2026, 8, 20, 18);
    final id = await archivio.apriSeduta(quando: inizio);
    await serie(id);
    await archivio.chiudiSeduta(id, quando: inizio.add(const Duration(hours: 1)));

    // ⚠️ È il caso degli esercizi scritti a mano dalle palestre: MET 5.0
    // (ripiego) × 80 × 1 = 400.
    expect((await leggi(id)).kcal, 400);
  });

  test('🚨 quello scritto a mano NON si sovrascrive', () async {
    final inizio = DateTime(2026, 8, 20, 18);
    final id = await archivio.apriSeduta(quando: inizio);
    await serie(id, met: 6);
    await archivio.correggiKcalSeduta(id, 800);
    await archivio.chiudiSeduta(id, quando: inizio.add(const Duration(hours: 1)));

    final s = await leggi(id);

    // La formula direbbe 480. Vince l'800 che ha scritto la persona.
    expect(s.kcal, 800);
    expect(s.kcalSource, 'manual');
  });

  test('le serie diventano LoggedSet, col nome copiato', () async {
    final id = await archivio.apriSeduta();
    await serie(id, met: 6);

    final s = await leggi(id);

    expect(s.sets, hasLength(1));
    expect(s.sets.first.exerciseName, 'Squat');
    expect(s.sets.first.reps, 10);
    expect(s.sets.first.weight, 60);
  });

  test('il titolo è il nome della scheda copiato al via', () async {
    // 🚨 Copiato, non risolto: una scheda archiviata o rinominata non deve
    // cambiare quello che lo storico dice di un allenamento di tre mesi fa.
    final id = await archivio.apriSeduta(nomeScheda: 'Full body A');

    expect((await leggi(id)).titolo, 'Full body A');
    expect(
      (await leggi(await archivio.apriSeduta())).titolo,
      'Sessione libera',
    );
  });
}
