import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🍎 **Le notifiche push su iPhone: la configurazione** — voce 26, 26/09/2026.
///
/// ══ 🚨 PERCHE' QUESTI TEST GUARDANO DEI FILE ════════════════════════════════
///
/// ⛔ Su iOS ogni pezzo mancante di questa configurazione produce lo **stesso**
/// sintomo: l'app parte, chiede il permesso, l'utente lo concede, e il token non
/// arriva mai. Nessun errore, nessun log, niente.
///
/// 🚨 **E non si può provare da qui**: serve un Mac, un iPhone vero e la firma.
/// 💡 Quindi si controlla quello che una macchina può controllare da sola — i
/// file — così quando finalmente si arriva davanti all'iPhone si sta cercando
/// un difetto solo, non quattro.
///
/// 📌 Sono gli stessi controlli che su Android hanno intercettato il difetto
/// dell'icona (`icona_delle_notifiche_test.dart`), applicati prima invece che
/// dopo.
void main() {
  File pbx() => File('ios/Runner.xcodeproj/project.pbxproj');

  /// 🔑 Per ogni configurazione di build, quale file di entitlements usa.
  Map<String, String> entitlementsPerConfigurazione() {
    final testo = pbx().readAsStringSync();

    /*
     * ⚠️ Dentro un blocco di configurazione `CODE_SIGN_ENTITLEMENTS` viene
     * **prima** di `name = <Configurazione>;`. 💡 Il `*?` tiene la coppia
     * dentro lo stesso blocco: senza, il primo entitlements si accoppierebbe
     * con l'ultimo nome del file.
     */
    final regola = RegExp(
      r'CODE_SIGN_ENTITLEMENTS = ([^;]+);[\s\S]*?name = (Debug|Release|Profile);',
    );

    return {
      for (final m in regola.allMatches(testo)) m.group(2)!: m.group(1)!.trim(),
    };
  }

  String? apsEnvironment(String file) => RegExp(
    r'<key>aps-environment</key>\s*<string>([^<]+)</string>',
  ).firstMatch(File(file).readAsStringSync())?.group(1);

  /// 🚨 **Il test che vale più di tutti**, perché chiude un difetto che c'era
  /// davvero: fino al 26/09 `RunnerDebug.entitlements` **esisteva e non lo
  /// leggeva nessuno** — tutte e tre le configurazioni puntavano a
  /// `Runner.entitlements`.
  ///
  /// ⛔ Fidarsi del nome del file avrebbe voluto dire scrivere `development`
  /// in un file morto, e ritrovarsi la build di sviluppo che chiede ad Apple
  /// l'ambiente di **produzione**: firma fallita, o notifiche che non arrivano.
  test('ogni configurazione punta al file di entitlements giusto', () {
    final quale = entitlementsPerConfigurazione();

    expect(
      quale.keys,
      containsAll(<String>['Debug', 'Release', 'Profile']),
      reason: 'non tutte le configurazioni dichiarano CODE_SIGN_ENTITLEMENTS',
    );

    expect(
      quale['Release'],
      'Runner/Runner.entitlements',
      reason: 'la build di rilascio deve usare gli entitlements di produzione',
    );

    /*
     * 💡 Debug **e** Profile: tutte e due si firmano con un profilo di
     * sviluppo, e un profilo di sviluppo ⛔ non ammette
     * `aps-environment: production` — la firma fallirebbe.
     */
    for (final configurazione in ['Debug', 'Profile']) {
      expect(
        quale[configurazione],
        'Runner/RunnerDebug.entitlements',
        reason:
            '$configurazione si firma con un profilo di sviluppo: con gli '
            'entitlements di produzione la firma fallisce',
      );
    }
  });

  /// ⚠️ E i due file devono dichiarare due ambienti **diversi**: se fossero
  /// uguali, averli separati non servirebbe a niente.
  test('gli entitlements dichiarano i due ambienti APNs, e sono diversi', () {
    expect(
      apsEnvironment('ios/Runner/Runner.entitlements'),
      'production',
      reason: 'senza aps-environment iOS non consegna niente, e non dice perché',
    );

    expect(
      apsEnvironment('ios/Runner/RunnerDebug.entitlements'),
      'development',
      reason: 'le build da Xcode vivono nel sandbox APNs, non in produzione',
    );
  });

  /// 💡 `remote-notification` permette al sistema di **svegliare l'app** quando
  /// arriva una notifica con l'app non in primo piano. ⛔ Senza, il carico utile
  /// può non essere consegnato e il tocco non sa più dove andare — lo stesso
  /// difetto visto su Android il 26/09, per una causa del tutto diversa.
  test('Info.plist dichiara remote-notification', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    final modi = RegExp(
      r'<key>UIBackgroundModes</key>\s*<array>([\s\S]*?)</array>',
    ).firstMatch(plist)?.group(1);

    expect(
      modi,
      isNotNull,
      reason: 'UIBackgroundModes non c\'è affatto in Info.plist',
    );
    expect(
      modi,
      contains('remote-notification'),
      reason: 'l\'app non verrà svegliata dalle notifiche',
    );
  });

  /// 🍎 **`GoogleService-Info.plist` dev'essere DENTRO il target**, non solo
  /// nella cartella — voce 26.6.
  ///
  /// ⛔ Copiare il file in `ios/Runner/` **non basta**: se non partecipa alla
  /// fase *Resources* non finisce nel bundle, e `Firebase.initializeApp()`
  /// fallisce esattamente come quando il file non c'è affatto. 🚨 Ed è il
  /// solito difetto muto: l'app parte, e le push non esistono.
  ///
  /// 💡 Il file in sé è fuori dal repo (come il gemello Android), quindi qui
  /// non si controlla che **esista**: si controlla che il progetto lo
  /// **aspetti**. Sono due cose diverse e solo la seconda è verificabile da qui.
  test('GoogleService-Info.plist partecipa alla fase Resources', () {
    final testo = pbx().readAsStringSync();

    final riferimento = RegExp(
      r'([0-9A-F]{24}) /\* GoogleService-Info\.plist \*/ = \{isa = PBXFileReference',
    ).firstMatch(testo)?.group(1);

    expect(
      riferimento,
      isNotNull,
      reason: 'il progetto Xcode non conosce affatto GoogleService-Info.plist',
    );

    final daCostruire = RegExp(
      '([0-9A-F]{24}) /\\* GoogleService-Info\\.plist in Resources \\*/ = '
      r'\{isa = PBXBuildFile; fileRef = ' '$riferimento',
    ).firstMatch(testo)?.group(1);

    expect(
      daCostruire,
      isNotNull,
      reason: 'il file è dichiarato ma non partecipa a nessuna fase di build',
    );

    /*
     * 🚨 E dev'essere la fase Resources **del target Runner**
     * (`97C146EC…`): nel progetto ce n'è una seconda, e metterlo in quella
     * sbagliata non lo farebbe finire nell'app.
     */
    final fase = RegExp(
      r'97C146EC1CF9000F007C117D /\* Resources \*/ = \{[\s\S]*?files = \(([\s\S]*?)\);',
    ).firstMatch(testo)?.group(1);

    expect(fase, isNotNull, reason: 'non si trova la fase Resources di Runner');
    expect(
      fase,
      contains(daCostruire!),
      reason:
          'il file non è nella fase Resources del target Runner: non finirà '
          'nel bundle, e Firebase non partirà',
    );
  });

  /// 🔑 **E il pacchetto dev'essere lo stesso di Android.** ⛔ Un bundle id
  /// diverso da quello registrato su Apple e su Firebase fa fallire le push
  /// senza un errore: è il tipo di svista che si trova solo all'ultimo.
  test('il bundle id iOS è quello registrato', () {
    final trovati = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
        .allMatches(pbx().readAsStringSync())
        .map((m) => m.group(1)!.trim())
        .toSet();

    expect(
      trovati,
      contains('com.smp.mytrainingcompanion'),
      reason: 'il bundle id non è quello registrato su Apple e su Firebase',
    );
  });
}
