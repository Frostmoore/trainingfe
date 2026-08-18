import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/scheda_catalogo.dart';

/// La ricerca nel catalogo di palestre e trainer — Parte M, 18/08/2026.
///
/// ── 🚨 `autoDispose`, e con la stessa ragione del catalogo alimenti ────────
///
/// Ogni ricerca è diversa dalla precedente, e tenerle in memoria vorrebbe dire
/// conservare un elenco di risultati per **ogni cosa** che una persona ha
/// digitato in questa sessione. ⚠️ E qui è peggio che con gli alimenti: sarebbe
/// una cronologia di **quali palestre stava guardando**.
final catalogoProvider = FutureProvider.autoDispose
    .family<List<SchedaCatalogo>, String>((ref, testo) async {
      final q = testo.trim();

      /*
       * 🚨 **La risposta si tiene per un minuto.**
       *
       * ⚠️ Qui non è solo una questione di freno: ogni chiamata al catalogo
       * **conta una visualizzazione** per le schede sponsorizzate, e quella è
       * una riga di fattura. Il server protegge già l'inserzionista contando
       * una persona al giorno, ma far partire due richieste per un refuso
       * corretto è comunque lavoro inutile per tutti.
       */
      final tenuto = ref.keepAlive();
      Timer? scadenza;

      ref.onDispose(() => scadenza?.cancel());
      ref.onCancel(() {
        scadenza = Timer(const Duration(minutes: 1), tenuto.close);
      });
      ref.onResume(() {
        scadenza?.cancel();
        scadenza = null;
      });

      // 💡 A differenza degli alimenti, qui si può cercare **anche a vuoto**:
      // il catalogo senza testo mostra chi c'è vicino, che è il caso normale
      // quando si apre la schermata.
      final elenco = await ref
          .watch(apiClientProvider)
          .get<List<dynamic>>(
            '/catalogo',
            query: q.isEmpty ? const {} : {'q': q},
          );

      return elenco
          .whereType<Map<String, dynamic>>()
          .map(SchedaCatalogo.fromJson)
          .toList(growable: false);
    });

/// Apre (o ritrova) la conversazione con una scheda del catalogo.
///
/// 🚨 Si manda `profilo_id`, **non** l'id di una persona: chi sia il
/// destinatario lo decide il server.
///
/// ⚠️ Il nome è `...DalCatalogo` e non `apriConversazione` perché **quello
/// esiste già** in `features/chat`, e fa un'altra cosa: apre un filo con una
/// persona che si conosce già, mandando il suo `user_id`. Due provider con lo
/// stesso nome sarebbero due import che si escludono a vicenda, e chi ne
/// importa uno per sbaglio manderebbe l'id sbagliato a un endpoint che non se
/// ne accorge.
final apriDalCatalogoProvider = Provider(
  (ref) => (int profiloId) async {
    final risposta = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/conversations/informazioni',
          body: {'profilo_id': profiloId},
        );

    return (
      id: (risposta['id'] as num).toInt(),

      /*
       * 🚨 `restanti` può essere `null`, e vuol dire **senza limite**.
       *
       * ⚠️ Convertirlo in `0` qui — la cosa che viene naturale scrivendo
       * `as int? ?? 0` — mostrerebbe a un abbonato un contatore a zero su una
       * chat in cui può scrivere quanto vuole.
       */
      restanti: (risposta['restanti'] as num?)?.toInt(),
      nome: (risposta['con'] as Map<String, dynamic>?)?['nome'] as String?,
    );
  },
);
