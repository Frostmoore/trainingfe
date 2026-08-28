import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/catalogo_esercizi.dart';

/// Il disegno dell'esercizio e chi l'ha fatto — 3b-L, 28/08/2026.
///
/// ══ 🚨 QUI SI ROMPE IN SILENZIO ═══════════════════════════════════════════
///
/// ⛔ Se `image_credit` si perde per strada non succede **niente di visibile
/// come errore**: succede che l'app non tinge il disegno. E il disegno è
/// bianco su trasparente, quindi su una card chiara **sparisce**.
///
/// 🚨 Il posto più facile in cui perderlo è la **copia locale**: `toJson()` e
/// `fromJson()` sono due liste di campi scritte a mano, e dimenticarne uno nel
/// primo non dà nessun avviso. ⚠️ Chi è offline vedrebbe un catalogo di
/// esercizi con le figure invisibili, e concluderebbe che si sono rotte le
/// immagini.
void main() {
  Map<String, dynamic> riga({Object? credito = 'Tizio — CC BY-SA 4.0'}) => {
    'id': 7,
    'name': 'Panca piana',
    'muscle_group': 'chest',
    'secondary_muscles': ['triceps'],
    'met': 5.0,
    'image_url': 'https://esempio/panca.png',
    'image_credit': credito,
  };

  group('il credito arriva dal server', () {
    test('si legge da image_credit', () {
      final e = EsercizioDelCatalogo.fromJson(riga());

      expect(e.credito, 'Tizio — CC BY-SA 4.0');
    });

    test('è null quando la foto l\'ha caricata la palestra', () {
      final e = EsercizioDelCatalogo.fromJson(riga(credito: null));

      expect(
        e.credito,
        isNull,
        reason:
            'Un credito su una foto altrui sarebbe falso: attribuirebbe a '
            'qualcun altro un lavoro che non ha fatto.',
      );
    });

    test('è null quando il server è vecchio e il campo non c\'è', () {
      final senza = riga()..remove('image_credit');

      expect(EsercizioDelCatalogo.fromJson(senza).credito, isNull);
    });
  });

  group('da dove viene l\'esercizio — 3b-N', () {
    test('si legge dal server', () {
      final j = riga()..['origine'] = 'mia';

      expect(EsercizioDelCatalogo.fromJson(j).origine, OrigineEsercizio.mia);
    });

    test('un valore che non conosciamo ricade su «piattaforma»', () {
      final j = riga()..['origine'] = 'qualcosa-di-nuovo';

      expect(
        EsercizioDelCatalogo.fromJson(j).origine,
        OrigineEsercizio.piattaforma,
        reason:
            'Il caso innocuo è mostrarlo fra quelli di tutti, non dire «è tuo» '
            'a qualcosa che non lo è.',
      );
    });

    test('un server vecchio, che il campo non lo manda, non rompe niente', () {
      final senza = riga()..remove('origine');

      expect(
        EsercizioDelCatalogo.fromJson(senza).origine,
        OrigineEsercizio.piattaforma,
      );
    });

    test('sopravvive alla copia locale', () {
      final j = riga()..['origine'] = 'condivisa';
      final partenza = EsercizioDelCatalogo.fromJson(j);

      final riletto = EsercizioDelCatalogo.fromJson(
        (jsonDecode(jsonEncode(partenza.toJson())) as Map).cast(),
      );

      expect(
        riletto.origine,
        OrigineEsercizio.condivisa,
        reason:
            'Se `toJson` lo dimentica, chi è offline vede tutti i propri '
            'esercizi finire fra quelli della piattaforma.',
      );
    });
  });

  group('il credito sopravvive alla copia locale', () {
    test('un giro completo di andata e ritorno non lo perde', () {
      final partenza = EsercizioDelCatalogo.fromJson(riga());

      /*
       * ⚠️ Lo stesso giro che fa `catalogoEserciziProvider`: elenco →
       * `jsonEncode` → stringa in cache → `jsonDecode` → elenco.
       */
      final salvato = jsonEncode([partenza.toJson()]);
      final riletto = (jsonDecode(salvato) as List)
          .map((e) => EsercizioDelCatalogo.fromJson((e as Map).cast()))
          .toList();

      expect(riletto.single.credito, partenza.credito);
      expect(riletto.single.immagine, partenza.immagine);
    });

    test('anche l\'assenza di credito sopravvive, e resta assenza', () {
      final partenza = EsercizioDelCatalogo.fromJson(riga(credito: null));

      final riletto = EsercizioDelCatalogo.fromJson(
        (jsonDecode(jsonEncode(partenza.toJson())) as Map).cast(),
      );

      expect(
        riletto.credito,
        isNull,
        reason:
            'Se l\'assenza tornasse come stringa vuota, l\'app tingerebbe una '
            'fotografia e la distruggerebbe.',
      );
    });
  });
}
