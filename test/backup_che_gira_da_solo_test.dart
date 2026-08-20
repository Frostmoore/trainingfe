import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_companion/src/core/backup/backup_che_gira_da_solo.dart';
import 'package:training_companion/src/core/backup/backup_controller.dart';

/// Il backup che gira da solo — FASE 2.1 (`N4.1`), 20/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// Il difetto più grave del piano: fino al 20/08 la copia di sicurezza girava
/// **solo** a mano o all'accensione dell'interruttore. Poi mai più.
///
/// ⚠️ Tutto il progetto sta su «i dati stanno sul telefono», e quella scelta
/// regge **solo se il backup funziona**. Chi non ce l'ha lo sa; chi ce l'ha e
/// non funziona **crede di essere al sicuro** — e lo scopre quando il telefono è
/// già rotto.
void main() {
  late _BackupFinto finto;
  late DateTime adesso;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    finto = _BackupFinto();
    adesso = DateTime(2026, 8, 20, 12);
  });

  ProviderContainer conta() {
    final c = ProviderContainer(
      overrides: [backupAutomaticoProvider.overrideWith(() => finto)],
    );

    addTearDown(c.dispose);

    return c;
  }

  BackupCheGiraDaSolo daSolo(ProviderContainer c) => BackupCheGiraDaSolo(
        c.read(_refProvider),
        adesso: () => adesso,
      );

  Future<void> segnaFattoIl(DateTime quando) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(
      BackupCheGiraDaSolo.chiaveUltimo,
      quando.millisecondsSinceEpoch,
    );
  }

  group('Quando NON deve fare niente', () {
    /// 🚨 Spento vuol dire spento: non si fa un backup a chi non l'ha chiesto,
    /// e caricare su Drive di nascosto sarebbe imperdonabile.
    test('con l interruttore spento', () async {
      finto.stato = const StatoBackup(acceso: false, disponibile: true);

      expect(await daSolo(conta()).forse(), isFalse);
      expect(finto.quanti, 0);
    });

    test('senza nessun cloud configurato', () async {
      finto.stato = const StatoBackup(acceso: true, disponibile: false);

      expect(await daSolo(conta()).forse(), isFalse);
      expect(finto.quanti, 0);
    });

    /// 💡 Un giorno, come chiede `plan_backup.md` §N4.1. Rifarlo a ogni
    /// apertura vorrebbe dire caricare su Drive dieci volte al giorno.
    test('se ne ha già fatto uno due ore fa', () async {
      finto.stato = const StatoBackup(acceso: true, disponibile: true);
      await segnaFattoIl(adesso.subtract(const Duration(hours: 2)));

      expect(await daSolo(conta()).forse(), isFalse);
      expect(finto.quanti, 0);
    });
  });

  group('Quando lo fa', () {
    /// 🚨 Il caso vero: l'app si apre il giorno dopo.
    test('se l ultimo è di venticinque ore fa', () async {
      finto.stato = const StatoBackup(acceso: true, disponibile: true);
      await segnaFattoIl(adesso.subtract(const Duration(hours: 25)));

      expect(await daSolo(conta()).forse(), isTrue);
      expect(finto.quanti, 1);
    });

    /// ⚠️ Nessuna data salvata vuol dire «non l'ho mai fatto **da qui**»: chi
    /// ha acceso l'interruttore prima che questo meccanismo esistesse deve
    /// esserne coperto **subito**, non fra un giorno.
    test('e se non ne ha mai fatto uno', () async {
      finto.stato = const StatoBackup(acceso: true, disponibile: true);

      expect(await daSolo(conta()).forse(), isTrue);
      expect(finto.quanti, 1);
    });

    test('e poi si ricorda quando', () async {
      finto.stato = const StatoBackup(acceso: true, disponibile: true);

      await daSolo(conta()).forse();

      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getInt(BackupCheGiraDaSolo.chiaveUltimo), isNotNull);
    });
  });

  group('Gli stati che la schermata mostra — N4.3', () {
    /// ══ 🚨 LO STATO CHE MANCAVA ═════════════════════════════════════════
    ///
    /// ⚠️ Fino a FASE 2.1 «fallito» non serviva: il backup partiva solo
    /// premendo un pulsante, e chi lo premeva vedeva l'errore. Da quando gira
    /// **da solo**, un fallimento succede alle tre di notte e non lo vede
    /// nessuno.
    ///
    /// 🚨 E la schermata continuava a dire «Ultimo backup: 3 giorni fa» — vero
    /// e fuorviante insieme.
    test('un fallimento si scrive, non solo si tace', () async {
      finto
        ..stato = const StatoBackup(acceso: true, disponibile: true)
        ..esplode = true;

      await daSolo(conta()).forse();

      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getInt(BackupCheGiraDaSolo.chiaveUltimoErrore), isNotNull);
    });

    /// 💡 Un successo cancella l'errore: una preferenza che non serve più è una
    /// cosa che qualcuno un giorno legge senza sapere che è scaduta.
    test('e un successo lo cancella', () async {
      finto
        ..stato = const StatoBackup(acceso: true, disponibile: true)
        ..esplode = true;

      final c = conta();
      await daSolo(c).forse();

      finto.esplode = false;
      await daSolo(c).forse();

      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getInt(BackupCheGiraDaSolo.chiaveUltimoErrore), isNull);
    });

    /// 🚨 `inErrore` è vero **solo** se il fallimento è più recente del
    /// successo. ⚠️ Un errore di due settimane fa, seguito da cinque backup
    /// riusciti, non è una cosa da mostrare: mostrarlo insegnerebbe a ignorare
    /// l'avviso, che è il modo di renderlo inutile per la volta in cui conta.
    test('un errore vecchio, seguito da un successo, non si mostra', () {
      const s = StatoBackup(
        acceso: true,
        disponibile: true,
        fallitoIl: null,
      );

      expect(s.inErrore, isFalse);

      final vecchio = StatoBackup(
        acceso: true,
        disponibile: true,
        fallitoIl: DateTime(2026, 8, 1),
        ultimo: DateTime(2026, 8, 15),
      );

      expect(vecchio.inErrore, isFalse, reason: 'Il successo è più recente.');
    });

    test('ma un errore dopo l ultimo successo si mostra', () {
      final s = StatoBackup(
        acceso: true,
        disponibile: true,
        ultimo: DateTime(2026, 8, 15),
        fallitoIl: DateTime(2026, 8, 18),
      );

      expect(s.inErrore, isTrue);
    });

    /// ⚠️ «Non è mai riuscito» è uno stato a sé: chi ha acceso l'interruttore e
    /// non ha **mai** avuto un backup è nel caso peggiore di tutti, e non deve
    /// finire nello stesso messaggio di chi ne ha uno vecchio.
    test('mai riuscito, e ha già fallito', () {
      final s = StatoBackup(
        acceso: true,
        disponibile: true,
        fallitoIl: DateTime(2026, 8, 18),
      );

      expect(s.inErrore, isTrue);
      expect(s.ultimo, isNull);
    });
  });

  group('Quando va storto', () {
    /// ⚠️ Lo chiama la sequenza di accesso: un backup che fallisce **non è una
    /// buona ragione** per far crollare l'apertura dell'app.
    test('non lancia mai', () async {
      finto
        ..stato = const StatoBackup(acceso: true, disponibile: true)
        ..esplode = true;

      await expectLater(daSolo(conta()).forse(), completion(isFalse));
    });

    /// ══ 🚨 IL TEST CHE CONTA DI PIÙ ═══════════════════════════════════════
    ///
    /// La data si scrive **solo se è andata bene**. ⚠️ Scrivendola comunque, un
    /// backup fallito comprerebbe **ventiquattro ore di silenzio**: si
    /// riproverebbe domani invece che alla prossima apertura, e chi ha la rete
    /// che va e viene resterebbe scoperto proprio nei giorni storti.
    test('un fallimento NON consuma la giornata', () async {
      finto
        ..stato = const StatoBackup(acceso: true, disponibile: true)
        ..esplode = true;

      await daSolo(conta()).forse();

      final prefs = await SharedPreferences.getInstance();

      expect(
        prefs.getInt(BackupCheGiraDaSolo.chiaveUltimo),
        isNull,
        reason: 'Senza data salvata, alla prossima apertura ci riprova.',
      );
    });

    /// 💡 E infatti ci riprova subito dopo, senza aspettare domani.
    test('e alla riapertura ci riprova', () async {
      finto
        ..stato = const StatoBackup(acceso: true, disponibile: true)
        ..esplode = true;

      final c = conta();

      await daSolo(c).forse();
      finto.esplode = false;

      expect(await daSolo(c).forse(), isTrue);
      expect(finto.quanti, 1);
    });
  });
}

/// 💡 Serve solo a farsi dare un `Ref` da dentro il contenitore: la classe ne
/// vuole uno, e in un test non c'è nessuna schermata che glielo passi.
final _refProvider = Provider<Ref>((ref) => ref);

class _BackupFinto extends BackupAutomatico {
  StatoBackup stato = const StatoBackup(acceso: false, disponibile: false);
  bool esplode = false;
  int quanti = 0;

  @override
  Future<StatoBackup> build() async => stato;

  @override
  Future<void> adesso() async {
    if (esplode) throw StateError('Drive non risponde');

    quanti++;
  }
}
