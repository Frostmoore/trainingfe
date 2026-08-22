import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Il riordino delle impostazioni — 3b-P, 22/08/2026.
///
/// ══ 🚨 PERCHE' TEST SUL SORGENTE E NON SUI WIDGET ═════════════════════════
///
/// ⚠️ Quello che va protetto qui non e' *come si disegna* una schermata, ma
/// **che una cosa sia in un posto e non in un altro**. 🚨 Una voce rimasta per
/// sbaglio in due posti non rompe niente e non si vede: si vede solo aprendo
/// due schermate di fila e ricordandosi cosa c'era nell'altra.
///
/// 💡 E' la stessa forma di `niente_nome_per_la_palestra_test.dart`, che il
/// 21/08 ha trovato il quinto punto che un grep aveva mancato.
void main() {
  String sorgente(String percorso) => File(percorso)
      .readAsStringSync()
      // 🚨 Gli a capo spariscono prima di cercare: una frase spezzata su due
      // righe e' invisibile a una ricerca ingenua, ed e' il modo in cui questo
      // progetto si e' gia' ingannato una volta.
      .replaceAll(RegExp(r'\s+'), ' ');

  group('3b-P.1 — la card del nome e le tre voci migrate', () {
    test('la card del nome porta a /profilo/tu', () {
      expect(sorgente('lib/src/features/profile/ui/profile_screen.dart'),
          contains('AppRoutes.tu'));
    });

    test('foto, citta e colore non sono piu nelle impostazioni', () {
      final s = sorgente('lib/src/features/profile/ui/profile_screen.dart');

      /*
       * ⛔ **Il difetto che questo test intercetta e' il doppione, non
       * l'assenza.** Spostare una voce e dimenticarsi di togliere l'originale
       * lascia due strade per la stessa cosa: funzionano tutte e due, e chi
       * cambia il colore da una non capisce perche' l'altra dice altro.
       */
      expect(s, isNot(contains('VoceAvatar(')));
      expect(s, isNot(contains('VoceCitta(')));
      expect(s, isNot(contains('ScegliColore')));
    });

    test('e stanno tutte e tre nella pagina nuova', () {
      final s = sorgente('lib/src/features/profile/ui/schermata_tu.dart');

      expect(s, contains('VoceAvatar('));
      expect(s, contains('VoceCitta('));
      expect(s, contains('SelettoreColore('));
    });

    test('il colore resta nascosto a chi ha una palestra', () {
      /*
       * 🚨 **La condizione e' migrata insieme al widget, ed e' la parte facile
       * da perdere.** Il selettore c'e' solo per chi non ha una palestra: le
       * tinte sono quelle della palestra, e lasciarle cambiare qui darebbe
       * un'app che si sveste al primo riallineamento del branding.
       *
       * ⚠️ Nel primo giro di questa fase il widget era stato spostato **senza**
       * la condizione: compilava, e mostrava il selettore a tutti.
       */
      final s = sorgente('lib/src/features/profile/ui/schermata_tu.dart');

      expect(s, contains('haPalestra'));
      expect(s, contains('if (!conPalestra)'));
    });
  });

  group('3b-P.2 — il peso e le bruciate', () {
    test('«Registra il peso» non e piu una voce delle impostazioni', () {
      expect(
        sorgente('lib/src/features/profile/ui/profile_screen.dart'),
        isNot(contains("Text('Registra il peso')")),
      );
    });

    test('la pesata sta in «I tuoi dati», e riusa WeightSheet', () {
      final s = sorgente(
        'lib/src/features/profile/ui/edit_profile_screen.dart',
      );

      // ⛔ `WeightSheet.mostra` e non un modulo nuovo: due form che salvano la
      // stessa cosa divergono al primo campo aggiunto.
      expect(s, contains('WeightSheet.mostra('));
      expect(s, contains('sommaLeBruciateProvider'));
    });

    test('nessuno calcola l obiettivo senza dichiarare la scelta', () {
      /*
       * ══ 🚨 IL TEST PIU' IMPORTANTE DI QUESTA FASE ═══════════════════════
       *
       * `TargetDelGiorno.scegli` ha `sommaLeBruciate` **obbligatorio**, quindi
       * un chiamante che se ne dimentica non compila. ⚠️ Ma un chiamante puo'
       * passare `true` fisso invece di leggere la preferenza, e **quello
       * compila**: sarebbe un'app che ignora l'interruttore in una sola delle
       * schermate che mostrano l'obiettivo.
       *
       * ⛔ E' esattamente la forma di O.D.15 e O.D.20 — due numeri per la
       * stessa cosa, nessun errore da nessuna parte.
       */
      final colpevoli = <String>[];

      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;

        final percorso = file.path.replaceAll(r'\', '/');
        if (percorso.endsWith('target_del_giorno.dart')) continue;

        final s = sorgente(percorso);
        if (!s.contains('TargetDelGiorno.scegli(')) continue;

        if (!s.contains('sommaLeBruciate: ref.watch(sommaLeBruciateProvider)')) {
          colpevoli.add(percorso);
        }
      }

      expect(
        colpevoli,
        isEmpty,
        reason:
            'chi calcola l\'obiettivo deve LEGGERE la preferenza, non '
            'passare un valore fisso',
      );
    });
  });

  group('3b-P.6 — la conferma del ripristino non sottostima', () {
    test('elenca tutto quello che viene sostituito', () {
      /*
       * ══ 🚨 QUESTA E' UNA QUESTIONE DI CONSENSO, NON DI TESTO ════════════
       *
       * ⚠️ La modale diceva «peso, misure e sonno». Da allora nel backup sono
       * entrati **gli allenamenti** (FASE 11), **le preferenze** (O.D.12) e le
       * foto.
       *
       * ⛔ Elencare tre voci su sei e' peggio di non elencarne nessuna: chi
       * legge conclude che le altre si salvino, e conferma. E' l'unica azione
       * dell'app da cui non si torna indietro.
       *
       * 🚨 **Questo test va aggiornato ogni volta che il backup cresce.** Se
       * diventa rosso perche' qualcuno ha aggiunto una tabella, la risposta
       * non e' togliere l'asserzione: e' aggiungere la parola alla modale.
       */
      final s = sorgente('lib/src/features/chiavi/ui/schermata_backup.dart');

      for (final famiglia in [
        'peso',
        'diario',
        'allenamenti',
        'sonno',
        'foto',
        'preferenze',
      ]) {
        expect(
          s,
          contains(famiglia),
          reason: 'la conferma non nomina «$famiglia»',
        );
      }

      // ⚠️ E il pulsante dice cosa fa: chi legge di fretta legge solo quello.
      expect(s, contains("Text('Sostituisci')"));
    });
  });
}
