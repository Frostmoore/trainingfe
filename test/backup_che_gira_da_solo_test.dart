import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_companion/src/core/backup/backup_che_gira_da_solo.dart';
import 'package:training_companion/src/core/backup/backup_controller.dart';
import 'package:training_companion/src/core/backup/cloud_di_backup.dart';

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

  /// 🚨 **Il cloud si sovrascrive, e non è un dettaglio del test.**
  ///
  /// ⚠️ `cloudDiBackupProvider` guarda `appConfigProvider`, che in un test
  /// **lancia apposta** finché `bootstrap()` non lo sovrascrive. Senza questo
  /// override `forse()` prenderebbe quell'eccezione e tornerebbe `fallito`:
  /// verde o rosso a caso, per una ragione che non c'entra niente col backup.
  ProviderContainer conta({bool conCloud = true}) {
    final c = ProviderContainer(
      overrides: [
        backupAutomaticoProvider.overrideWith(() => finto),
        cloudDiBackupProvider.overrideWithValue(
          conCloud ? _CloudFinto() : null,
        ),
      ],
    );

    addTearDown(c.dispose);

    return c;
  }

  BackupCheGiraDaSolo daSolo(ProviderContainer c) =>
      BackupCheGiraDaSolo(c.read(_refProvider), adesso: () => adesso);

  /// Accende l'interruttore **nelle preferenze**.
  ///
  /// ══ 🚨 DAL 24/08/2026 È LÌ CHE `forse()` GUARDA ═══════════════════════
  ///
  /// ⛔ Prima leggeva `backupAutomaticoProvider`, e per costruirsi quel
  /// provider chiede a Drive quand'è stato l'ultimo backup: cioè l'app parlava
  /// con Google **solo per decidere se fosse ora**. Su Android quella chiamata
  /// può disegnare, e infatti disegnava — il foglio «Accesso» sopra la
  /// schermata di blocco.
  ///
  /// 💡 Adesso le tre domande che decidono si rispondono dalle preferenze, e i
  /// test devono scrivere lì quello che prima mettevano nel finto.
  Future<void> accendiDavvero() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(BackupAutomatico.chiaveAcceso, true);
  }

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

      expect(await daSolo(conta()).forse(), EsitoBackup.spento);
      expect(finto.quanti, 0);
    });

    test('senza nessun cloud configurato', () async {
      await accendiDavvero();
      finto.stato = const StatoBackup(acceso: true, disponibile: false);

      // ⚠️ **Senza cloud vuol dire `cloudDiBackupProvider` nullo**, non uno
      // stato che dice di no: dal 24/08 è lì che `forse()` guarda, e chiederlo
      // allo stato vorrebbe dire passare da Drive per saperlo.
      expect(await daSolo(conta(conCloud: false)).forse(), EsitoBackup.spento);
      expect(finto.quanti, 0);
    });

    /// 💡 Un giorno, come chiede `plan_backup.md` §N4.1. Rifarlo a ogni
    /// apertura vorrebbe dire caricare su Drive dieci volte al giorno.
    test('se ne ha già fatto uno due ore fa', () async {
      await accendiDavvero();
      finto.stato = const StatoBackup(acceso: true, disponibile: true);
      await segnaFattoIl(adesso.subtract(const Duration(hours: 2)));

      /*
       * 🚨 **`nonEraOra`, non un `false` qualunque** — difetto del 22/08/2026.
       *
       * ⚠️ Prima erano tutti `false`, e chi stampava scriveva «non era ora» per
       * tutti e tre i casi. Il committente ha tenuto il telefono in carica una
       * notte per capire se il backup partiva, e ha letto «non era ora» mentre
       * la verità era che Google Drive non è collegato.
       */
      expect(await daSolo(conta()).forse(), EsitoBackup.nonEraOra);
      expect(finto.quanti, 0);
    });
  });

  group('Quando lo fa', () {
    /// 🚨 Il caso vero: l'app si apre il giorno dopo.
    test('se l ultimo è di venticinque ore fa', () async {
      await accendiDavvero();
      finto.stato = const StatoBackup(acceso: true, disponibile: true);
      await segnaFattoIl(adesso.subtract(const Duration(hours: 25)));

      expect((await daSolo(conta()).forse()).eRiuscito, isTrue);
      expect(finto.quanti, 1);
    });

    /// ⚠️ Nessuna data salvata vuol dire «non l'ho mai fatto **da qui**»: chi
    /// ha acceso l'interruttore prima che questo meccanismo esistesse deve
    /// esserne coperto **subito**, non fra un giorno.
    test('e se non ne ha mai fatto uno', () async {
      await accendiDavvero();
      finto.stato = const StatoBackup(acceso: true, disponibile: true);

      expect((await daSolo(conta()).forse()).eRiuscito, isTrue);
      expect(finto.quanti, 1);
    });

    test('e poi si ricorda quando', () async {
      await accendiDavvero();
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
      await accendiDavvero();
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
      await accendiDavvero();
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
      const s = StatoBackup(acceso: true, disponibile: true, fallitoIl: null);

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

  group('⛔ Il foglio di Google all avvio — difetto del 24/08/2026', () {
    /*
     * ══ 🚨 COSA È SUCCESSO ═══════════════════════════════════════════════
     *
     * Aprendo l'app, il foglio «Accesso» di Google saliva **sopra la schermata
     * di blocco**, rubava il fuoco al prompt dell'impronta e lo faceva fallire:
     * la schermata diceva *«Non è andata. Riprova»*. Misurato con venti
     * schermate a 0,2 s l'una.
     *
     * ⛔ La causa non era il backup: era che per **decidere se fosse ora** si
     * leggeva `backupAutomaticoProvider`, e quel provider per costruirsi chiede
     * a Drive quand'è stato l'ultimo backup. Su Android
     * `attemptLightweightAuthentication()` **può disegnare** — la
     * documentazione del plugin lo dice: *«Possible examples include … One Tap
     * on Android»*.
     *
     * 💡 Quindi: l'app parlava con Google a **ogni apertura**, solo per
     * scoprire che non era ora di fare niente.
     */
    test('spento: non si legge nemmeno lo stato', () async {
      finto.stato = const StatoBackup(acceso: true, disponibile: true);

      expect(await daSolo(conta()).forse(), EsitoBackup.spento);
      expect(
        finto.quanteLetture,
        0,
        reason: 'Ha chiesto a Drive per scoprire che il backup è spento.',
      );
    });

    /// 🚨 **È il caso di tutti i giorni**: l'app si apre dieci volte, e nove
    /// non è ora. Nessuna di quelle nove deve toccare Google.
    test('non è ora: non si legge nemmeno lo stato', () async {
      await accendiDavvero();
      finto.stato = const StatoBackup(acceso: true, disponibile: true);
      await segnaFattoIl(adesso.subtract(const Duration(hours: 2)));

      expect(await daSolo(conta()).forse(), EsitoBackup.nonEraOra);
      expect(
        finto.quanteLetture,
        0,
        reason: 'Ha chiesto a Drive solo per scoprire che non era ora.',
      );
    });

    /// 💡 E quando invece **è** ora, allora sì: lì una chiamata a Google è
    /// legittima, perché si sta facendo il backup davvero.
    test('quando è ora, allora lo stato si legge', () async {
      await accendiDavvero();
      finto.stato = const StatoBackup(acceso: true, disponibile: true);

      expect((await daSolo(conta()).forse()).eRiuscito, isTrue);
      expect(finto.quanteLetture, 1);
    });
  });

  group('⛔ Quando Drive va ricollegato, l automatico si ferma', () {
    /*
     * 🚨 **Non è «la rete non va».** L'autorizzazione a Drive è sparita, e
     * rifarla richiede la persona: riprovare a ogni apertura vorrebbe dire far
     * ricomparire il foglio di Google **per sempre**.
     *
     * ⚠️ Ed è diverso anche da «fallito»: quello riprova domani, e va bene.
     */
    test('la prima volta lo scopre e lo segna', () async {
      await accendiDavvero();
      finto
        ..stato = const StatoBackup(acceso: true, disponibile: true)
        ..serveRicollegare = true;

      expect(await daSolo(conta()).forse(), EsitoBackup.daRicollegare);

      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getBool(BackupCheGiraDaSolo.chiaveDaRicollegare), isTrue);
    });

    /// ⛔ **E dalla seconda in poi non ci prova nemmeno.** È la riga che
    /// impedisce al foglio di Google di ricomparire a ogni apertura.
    test('e dalla volta dopo non tocca più niente', () async {
      await accendiDavvero();
      finto
        ..stato = const StatoBackup(acceso: true, disponibile: true)
        ..serveRicollegare = true;

      final c = conta();
      await daSolo(c).forse();

      final lettureDopoIlPrimo = finto.quanteLetture;

      expect(await daSolo(c).forse(), EsitoBackup.daRicollegare);
      expect(
        finto.quanteLetture,
        lettureDopoIlPrimo,
        reason: 'Ci ha riprovato, e il foglio di Google ricomparirebbe.',
      );
    });

    /// 🚨 **Fermarsi in silenzio sarebbe la cosa peggiore**: chi ha acceso
    /// l'interruttore continuerebbe a credersi coperto.
    test('e la schermata lo dice', () {
      const s = StatoBackup(
        acceso: true,
        disponibile: true,
        daRicollegare: true,
      );

      expect(s.daRicollegare, isTrue);
    });

    /// 💡 Solo ricollegarsi lo rimette in moto, ed è giusto che sia così: è
    /// l'unico momento in cui una persona ha davvero ridato il permesso.
    test('e un fallimento normale NON lo ferma', () async {
      await accendiDavvero();
      finto
        ..stato = const StatoBackup(acceso: true, disponibile: true)
        ..esplode = true;

      expect(await daSolo(conta()).forse(), EsitoBackup.fallito);

      final prefs = await SharedPreferences.getInstance();

      expect(
        prefs.getBool(BackupCheGiraDaSolo.chiaveDaRicollegare),
        isNull,
        reason: 'Una rete che non va non è un permesso da ridare.',
      );
    });
  });

  group('Quando va storto', () {
    /// ⚠️ Lo chiama la sequenza di accesso: un backup che fallisce **non è una
    /// buona ragione** per far crollare l'apertura dell'app.
    test('non lancia mai', () async {
      await accendiDavvero();
      finto
        ..stato = const StatoBackup(acceso: true, disponibile: true)
        ..esplode = true;

      // ⛔ `fallito`: ci ha provato e non ce l'ha fatta. È l'unico esito che
      // merita di comparire a schermo.
      await expectLater(
        daSolo(conta()).forse(),
        completion(EsitoBackup.fallito),
      );
    });

    /// ══ 🚨 IL TEST CHE CONTA DI PIÙ ═══════════════════════════════════════
    ///
    /// La data si scrive **solo se è andata bene**. ⚠️ Scrivendola comunque, un
    /// backup fallito comprerebbe **ventiquattro ore di silenzio**: si
    /// riproverebbe domani invece che alla prossima apertura, e chi ha la rete
    /// che va e viene resterebbe scoperto proprio nei giorni storti.
    test('un fallimento NON consuma la giornata', () async {
      await accendiDavvero();
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
      await accendiDavvero();
      finto
        ..stato = const StatoBackup(acceso: true, disponibile: true)
        ..esplode = true;

      final c = conta();

      await daSolo(c).forse();
      finto.esplode = false;

      expect((await daSolo(c).forse()).eRiuscito, isTrue);
      expect(finto.quanti, 1);
    });
  });
}

/// 💡 Serve solo a farsi dare un `Ref` da dentro il contenitore: la classe ne
/// vuole uno, e in un test non c'è nessuna schermata che glielo passi.
final _refProvider = Provider<Ref>((ref) => ref);

/// Un cloud che esiste e basta.
///
/// 💡 `forse()` non lo usa mai: gli serve solo sapere se **ce n'è uno**. Il
/// lavoro vero lo fa `BackupAutomatico.adesso()`, che qui è finto.
class _CloudFinto implements CloudDiBackup {
  @override
  String get nome => 'Finto';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Il cloud finto non deve essere usato.');
}

class _BackupFinto extends BackupAutomatico {
  StatoBackup stato = const StatoBackup(acceso: false, disponibile: false);
  bool esplode = false;
  int quanti = 0;

  /// Quante volte qualcuno ha **letto lo stato** — 24/08/2026.
  ///
  /// 🚨 Non è una curiosità: costruire questo provider, nell'app vera, vuol
  /// dire **chiedere a Google Drive** quand'è stato l'ultimo backup. Contare le
  /// costruzioni è l'unico modo, in un test, di dimostrare che l'avvio non
  /// parla con Google quando non serve.
  int quanteLetture = 0;

  /// L'errore che l'oggetto vero solleva quando l'autorizzazione non c'è più.
  bool serveRicollegare = false;

  @override
  Future<StatoBackup> build() async {
    quanteLetture++;

    return stato;
  }

  @override
  Future<void> adesso() async {
    if (serveRicollegare) {
      throw const CloudNonRaggiungibile(
        'Non sei collegato a Google Drive.',
        serveRicollegare: true,
      );
    }

    if (esplode) throw StateError('Drive non risponde');

    quanti++;
  }
}
