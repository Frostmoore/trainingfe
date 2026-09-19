import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';

/// 🍽️ **Gli alimenti che uno si inventa restano suoi** — D7, 19/09/2026.
///
/// 📌 Il committente: *«gli alimenti di un utente restano i suoi e li vede solo
/// lui perché stanno sul suo telefono»*. 💡 Stanno già nel diario: la ricerca
/// li ritrova lì, anche senza rete.
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  Future<void> scrivi(
    String descrizione, {
    String fonte = 'manual',
    double? kcal100 = 120,
    DateTime? quando,
  }) => archivio.scriviVoceDiario(
    VociDiarioCompanion.insert(
      mangiatoIl: quando ?? DateTime(2026, 9, 18, 12),
      pasto: 'lunch',
      descrizione: descrizione,
      kcal100: Value(kcal100),
      fonte: Value(fonte),
    ),
  );

  test('si ritrovano cercando, uno per nome', () async {
    await scrivi('Torta della nonna', kcal100: 300);
    await scrivi(
      'torta della nonna',
      kcal100: 320,
      quando: DateTime(2026, 9, 19, 12),
    );

    final trovati = await archivio.alimentiScrittiDaMe('torta');

    expect(trovati, hasLength(1));
    expect(trovati.single.kcal100, 320, reason: 'Il più recente.');
  });

  /// ⛔ Quelli presi dal catalogo o da un piano il catalogo li ha già.
  test('solo quelli scritti da sé o stimati', () async {
    await scrivi('Pane dal catalogo', fonte: 'catalog');
    await scrivi('Pane stimato', fonte: 'ai_text');

    final trovati = await archivio.alimentiScrittiDaMe('pane');

    expect(trovati.map((a) => a.nome), ['Pane stimato']);
  });

  /// ⚠️ Riusato dalla ricerca diventa una voce `catalog` più recente: non deve
  /// nasconderlo.
  test('riusarlo non lo fa sparire', () async {
    await scrivi('Frittata mia');
    await scrivi(
      'Frittata mia',
      fonte: 'catalog',
      quando: DateTime(2026, 9, 20, 12),
    );

    expect(await archivio.alimentiScrittiDaMe('fritt'), hasLength(1));
  });

  test('senza valori per 100 g non è un alimento da riproporre', () async {
    await scrivi('Qualcosa', kcal100: null);

    expect(await archivio.alimentiScrittiDaMe('qualc'), isEmpty);
  });
}
