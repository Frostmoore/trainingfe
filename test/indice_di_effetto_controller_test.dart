import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/forma/indice_di_effetto_controller.dart';
import 'package:training_companion/src/features/health/dati_salute.dart';
import 'package:training_companion/src/features/health/health_controller.dart';
import 'package:training_companion/src/features/profile/data/profile_models.dart';
import 'package:training_companion/src/features/profile/profile_controller.dart';

/// Cosa serve al TEI per esistere — 08/09/2026.
///
/// ══ 🚨 COSA DIFENDONO QUESTI TEST ════════════════════════════════════════
///
/// ⛔ **Che nessuno metta un ripiego dove manca un dato.** Il TEI ha tre
/// ingredienti — età, battito a riposo, battiti della settimana — e per ognuno
/// esiste un numero «ragionevole» che qualcuno prima o poi sarà tentato di
/// scriverci: 40 anni, 60 bpm a riposo.
///
/// 🚨 **Quel numero produrrebbe un TEI plausibile e falso**, e nessuno se ne
/// accorgerebbe: la riserva di Karvonen è tutta lì dentro, e dieci battiti di
/// differenza su una riserva di novanta sono l'11%.
void main() {
  const profilo = UserProfile(
    mealHours: <String, String>{},
    missing: <String>[],
    activityLevels: <String, String>{},
    goals: <String, String>{},
    sex: 'male',
    age: 38,
  );

  LetturaSalute lettura(MetricaSalute m, double valore, DateTime quando) =>
      LetturaSalute(
        id: 0,
        fonte: 'test',
        metrica: m.codice,
        misurataIl: quando,
        giorno: DateTime(quando.year, quando.month, quando.day),
        valore: valore,
      );

  /// Un contenitore con un archivio vero (in memoria) e un profilo deciso qui.
  Future<(ProviderContainer, ArchivioSalute)> conta({
    UserProfile? conProfilo,
    bool conBattiti = true,
    bool conRiposo = true,
  }) async {
    final archivio = ArchivioSalute.inMemoria();
    final adesso = DateTime.now();

    if (conBattiti) {
      /*
       * ⚠️ **Un campione al minuto per un'ora**, come il telefono vero: la sonda
       * dell'08/09 ne ha contati 1.438 in due giorni. 💡 A questa densità
       * `affidabile` è `true`, ed è la condizione in cui il TEI ha senso.
       */
      await archivio.scriviLetture([
        for (var i = 0; i < 60; i++)
          lettura(
            MetricaSalute.battitoMedio,
            140,
            adesso.subtract(Duration(minutes: 90 - i)),
          ),
      ]);
    }

    if (conRiposo) {
      await archivio.scriviLetture([
        lettura(
          MetricaSalute.battitoARiposo,
          58,
          adesso.subtract(const Duration(hours: 6)),
        ),
      ]);
    }

    final c = ProviderContainer(
      overrides: [
        archivioSaluteProvider.overrideWithValue(archivio),
        if (conProfilo != null)
          profileProvider.overrideWith((ref) async => conProfilo),
      ],
    );

    addTearDown(c.dispose);
    addTearDown(archivio.close);

    /*
     * ⛔ **Senza un ascoltatore il provider muore prima di rispondere.**
     * 🚨 E' `autoDispose`: `read(.future)` non basta a tenerlo in vita, e
     * l'errore che arriva — *«disposed during loading state»* — parla di stati
     * interni invece che della causa.
     */
    c.listen(indiceDiEffettoProvider, (_, _) {});

    return (c, archivio);
  }

  test('✅ con i tre ingredienti il TEI esiste ed è affidabile', () async {
    final (c, _) = await conta(conProfilo: profilo);

    final tei = await c.read(indiceDiEffettoProvider.future);

    expect(tei, isNotNull);
    expect(tei!.affidabile, isTrue);

    /*
     * 💡 Un'ora a 140 bpm con riposo 58 e 38 anni: la riserva è ben sopra la
     * soglia del 30%, quindi i punti ci sono. ⚠️ Non si verifica il **valore** —
     * quello lo fa `indice_di_effetto_test`, che prova la curva.
     */
    expect(tei.punti, greaterThan(0));
    expect(tei.minutiUtili, greaterThan(0));
  });

  test('⛔ senza età non si inventa un’età', () async {
    /*
     * 🚨 La massima si stima con Tanaka (208 − 0,7 × età). Un «diciamo 40»
     * sposta la massima di dieci battiti, e con essa tutta la riserva.
     */
    final (c, _) = await conta(
      conProfilo: const UserProfile(
        mealHours: <String, String>{},
        missing: <String>[],
        activityLevels: <String, String>{},
        goals: <String, String>{},
        sex: 'male',
      ),
    );

    expect(await c.read(indiceDiEffettoProvider.future), isNull);
  });

  test('⛔ senza battito a riposo non si mette un 60 di comodo', () async {
    /*
     * 🚨 È **metà** della riserva di Karvonen: è quello che rende il TEI di una
     * persona diverso da quello di un'altra a parità di corsa.
     */
    final (c, _) = await conta(conProfilo: profilo, conRiposo: false);

    expect(await c.read(indiceDiEffettoProvider.future), isNull);
  });

  test('⛔ e senza battiti non c’è niente da contare', () async {
    final (c, _) = await conta(conProfilo: profilo, conBattiti: false);

    expect(await c.read(indiceDiEffettoProvider.future), isNull);
  });

  test('⚠️ con campioni radi il TEI c’è ma NON è affidabile', () async {
    /*
     * ⛔ **È la distinzione che tiene in piedi tutto.** Un TEI basso perché ti
     * sei mosso poco e uno basso perché l'orologio era nel cassetto sono la
     * stessa cifra e due cose opposte: la scheda mostra un «—» invece del
     * numero, e lo dice.
     */
    final archivio = ArchivioSalute.inMemoria();
    final adesso = DateTime.now();

    addTearDown(archivio.close);

    // 💡 Quattro campioni in tre giorni: l'orologio messo ogni tanto.
    await archivio.scriviLetture([
      for (var i = 0; i < 4; i++)
        lettura(
          MetricaSalute.battitoMedio,
          140,
          adesso.subtract(Duration(hours: 12 * (i + 1))),
        ),
      lettura(
        MetricaSalute.battitoARiposo,
        58,
        adesso.subtract(const Duration(hours: 6)),
      ),
    ]);

    final c = ProviderContainer(
      overrides: [
        archivioSaluteProvider.overrideWithValue(archivio),
        profileProvider.overrideWith((ref) async => profilo),
      ],
    );

    addTearDown(c.dispose);

    c.listen(indiceDiEffettoProvider, (_, _) {});

    final tei = await c.read(indiceDiEffettoProvider.future);

    expect(tei, isNotNull);
    expect(
      tei!.affidabile,
      isFalse,
      reason: 'quattro campioni in tre giorni non sono una misura',
    );
  });
}
