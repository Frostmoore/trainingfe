import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/alimento_catalogo.dart';

/// La ricerca nel catalogo alimenti — 17/08/2026.
///
/// ── 🚨 `autoDispose`, ed è il contrario del contatore dei gettoni ──────────
///
/// Il saldo dei gettoni **non** è `autoDispose` perché è un numero solo, sempre
/// lo stesso, su una schermata che si apre e si chiude di continuo. Qui è
/// l'opposto: ogni ricerca è diversa dalla precedente, e tenerle in memoria
/// vorrebbe dire conservare un elenco di risultati per **ogni cosa** che una
/// persona ha digitato in questa sessione.
///
/// ⚠️ E sarebbe anche una piccola cronologia di quello che quella persona stava
/// cercando di mangiare, tenuta in memoria senza motivo.
final ricercaAlimentiProvider = FutureProvider.autoDispose
    .family<List<AlimentoCatalogo>, String>((ref, testo) async {
      final q = testo.trim();

      // 💡 Lo stesso minimo che applica il server. Ripeterlo qui evita una
      // richiesta che si sa già che tornerà `422`.
      if (q.length < 2) return const [];

      /*
       * 🚨 **La risposta si tiene per un minuto.**
       *
       * Chi scrive «pol», cancella e riscrive «pol» — cosa che capita di
       * continuo mentre si corregge una parola — non deve far partire due
       * richieste. ⚠️ Senza, il freno del server (60 al minuto) si consuma
       * correggendo i refusi.
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

      // 💡 `List` e non `Map`: il client scarta gia' l'involucro `data`, e
      // chiedere una mappa qui darebbe un errore di tipo a ogni ricerca.
      final elenco = await ref
          .watch(apiClientProvider)
          .get<List<dynamic>>('/foods/search', query: {'q': q});

      return elenco
          .whereType<Map<String, dynamic>>()
          .map(AlimentoCatalogo.fromJson)
          .toList(growable: false);
    });
