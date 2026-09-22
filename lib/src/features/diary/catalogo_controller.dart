import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/storage/archivio_salute.dart';
import '../health/health_controller.dart';
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
      /*
       * ══ 🆕 PRIMA I SUOI, CHE STANNO SUL TELEFONO — D7, 19/09/2026 ══════════
       *
       * 📌 *«gli alimenti di un utente restano i suoi e li vede solo lui
       * perché stanno sul suo telefono»*. 💡 Un alimento inventato non va al
       * server: si ritrova qui, cercando nel suo diario — anche senza rete.
       *
       * ⚠️ `id: 0`: non ha un id nel catalogo, e non deve averlo — nessuno lo
       * usa per rimandarlo al server.
       */
      final archivio = ref.read(archivioSaluteProvider);
      final scrittiDaMe = await archivio.alimentiScrittiDaMe(q);

      // 🆕 A4 — la foto dei suoi, in una lettura sola per tutta la ricerca.
      final foto = await archivio.fotoDegliAlimentiMieiPer(
        scrittiDaMe.map((a) => a.nome),
      );

      final suoi = [
        for (final a in scrittiDaMe)
          AlimentoCatalogo(
            id: 0,
            nome: a.nome,
            kcal100: a.kcal100,
            proteine100: a.proteine100,
            carboidrati100: a.carboidrati100,
            grassi100: a.grassi100,
            note: 'Scritto da te',
            fotoLocale: foto[ArchivioSalute.chiaveAlimento(a.nome)],
          ),
      ];

      List<AlimentoCatalogo> dalServer;

      try {
        final elenco = await ref
            .watch(apiClientProvider)
            .get<List<dynamic>>('/foods/search', query: {'q': q});

        dalServer = elenco
            .whereType<Map<String, dynamic>>()
            .map(AlimentoCatalogo.fromJson)
            .toList(growable: false);
      } on Object {
        // 💡 Senza rete restano i suoi: meglio di un errore.
        if (suoi.isNotEmpty) return suoi;

        rethrow;
      }

      final nomi = {for (final a in suoi) a.nome.trim().toLowerCase()};

      return [
        ...suoi,
        for (final a in dalServer)
          if (!nomi.contains(a.nome.trim().toLowerCase())) a,
      ];
    });
