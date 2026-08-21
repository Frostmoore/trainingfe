/// I messaggi «una volta sola» — N16.3, N16.4.
///
/// ── 🚨 Il momento in cui «è stato visto» va costruito, non indovinato ─────
///
/// Per una foto sarebbe chiaro: si apre a schermo intero. **Per il testo no** —
/// un messaggio dentro una lista è già letto nell'istante in cui la lista si
/// disegna, e non esisterebbe nessun momento in cui cancellarlo.
///
/// 💡 Per questo un contenuto usa e getta arriva **coperto**: *«Tocca per
/// leggere»*. Si apre, si guarda, si chiude, sparisce. ⚠️ Senza questo la
/// funzione sarebbe indefinita, e cancellerebbe messaggi che nessuno ha letto.

library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/crypto/cifratura_allegati.dart';
import '../../../../core/crypto/contenuto_messaggio.dart';
import '../../../../core/crypto/providers_crypto.dart';
import '../../../../core/media/archivio_foto.dart';
import '../../../../core/media/schermo_protetto.dart';
import '../../../../core/media/tipo_foto.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../chat_controller.dart';
import '../../data/allegato_di_chat.dart';

/// La nuvoletta coperta: quello che c'è dentro si scopre toccando.
class UsaEGettaCoperta extends ConsumerWidget {
  const UsaEGettaCoperta({
    required this.messaggio,
    required this.contenuto,
    required this.mio,
    required this.conversationId,
    super.key,
  });

  final ChatMessage messaggio;
  final ContenutoMessaggio contenuto;
  final bool mio;
  final int conversationId;

  bool get _eFoto => contenuto is ContenutoFoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final colori = tema.colorScheme;

    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Gap.radius),
          border: Border.all(color: colori.outlineVariant),
          color: colori.surfaceContainerHighest,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Gap.radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(Gap.radius),
            onTap: () => _apri(context, ref),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_outlined,
                    color: colori.primary,
                  ),
                  const SizedBox(width: Gap.sm),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _eFoto
                              ? 'Foto una volta sola'
                              : 'Messaggio una volta sola',
                          style: tema.textTheme.labelLarge,
                        ),
                        Text(
                          /*
                           * 💡 A chi manda si dice una cosa diversa: la sua
                           * copia non si brucia toccandola, e va detto —
                           * altrimenti non la aprirebbe mai per paura di
                           * consumarla.
                           */
                          mio ? 'Tocca per rivedere' : 'Tocca per leggere',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: colori.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _apri(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LetturaUsaEGetta(contenuto: contenuto),
      ),
    );

    /*
     * 🚨 **Si brucia alla CHIUSURA, e solo per chi riceve.**
     *
     * ⚠️ `crypto_box` permette a chi ha scritto di rileggere i propri messaggi:
     * se il suo tocco contasse come «visto», si toglierebbe da solo le
     * ventiquattro ore che gli spettano. Il controllo c'è anche sul server —
     * questo qui evita solo una chiamata inutile.
     */
    if (mio) return;

    /*
     * 🚨 **Via la riga E il file** — N16.4.
     *
     * Il server smette di consegnare la busta, ma il file era gia' sul telefono:
     * senza questa riga resterebbe in `Cache/foto/effimere/` fino alla spazzata
     * delle ventiquattro ore. ⚠️ Non finirebbe in nessun backup — la cache e'
     * esclusa per costruzione — ma resterebbe **leggibile per un giorno** su un
     * telefono a cui era stato promesso «una volta sola».
     *
     * 💡 Prima il file, poi il server: se la rete cade, la copia locale e'
     * comunque sparita, e la busta si spegnera' alla prossima apertura.
     */
    if (contenuto is ContenutoFoto) {
      final busta = contenuto as ContenutoFoto;

      try {
        await const ArchivioFoto().cancella(
          AllegatoDiChat.percorsoDi(busta.token, TipoFoto.effimere),
        );
      } on Object {
        // ⚠️ Non si blocca niente: la spazzata delle 24 ore lo riprende.
      }
    }

    await ref
        .read(threadProvider(conversationId).notifier)
        .segnaVista(messaggio.id);
  }
}

/// La schermata di lettura, protetta dalle schermate — N16.7.
class LetturaUsaEGetta extends ConsumerStatefulWidget {
  const LetturaUsaEGetta({required this.contenuto, super.key});

  final ContenutoMessaggio contenuto;

  @override
  ConsumerState<LetturaUsaEGetta> createState() => _LetturaUsaEGettaState();
}

class _LetturaUsaEGettaState extends ConsumerState<LetturaUsaEGetta> {
  @override
  void initState() {
    super.initState();

    SchermoProtetto.accendi();
  }

  @override
  void dispose() {
    /*
     * 🚨 **Si spegne sempre.** Il flag sta sulla finestra, non sulla schermata:
     * acceso e dimenticato resterebbe attivo su tutta l'app, e il sintomo — «non
     * riesco più a fare schermate del diario» — non somiglierebbe mai alla sua
     * causa.
     */
    SchermoProtetto.spegni();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contenuto = widget.contenuto;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Una volta sola'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: switch (contenuto) {
                  ContenutoFoto() => _FotoEffimera(busta: contenuto),
                  ContenutoTesto(:final testo) => SingleChildScrollView(
                    padding: const EdgeInsets.all(Gap.lg),
                    child: SelectableText(
                      testo,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                  _ => const Padding(
                    padding: EdgeInsets.all(Gap.lg),
                    child: Text(
                      'Questo contenuto richiede una versione più recente dell\'app.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                },
              ),
            ),

            /*
             * 🚨 **Il limite, scritto dove qualcuno lo legge** — N16.9.
             *
             * ⚠️ Non possiamo impedire che chi guarda conservi quello che ha
             * visto: si può fotografare lo schermo con un altro telefono, e un
             * programma modificato tiene tutto. Promettere una sicurezza che non
             * c'è è peggio che non offrire la funzione, perché qualcuno
             * manderebbe qualcosa che non avrebbe mandato.
             */
            const Padding(
              padding: EdgeInsets.all(Gap.md),
              child: Text(
                'Chiudendo, questo contenuto sparisce da qui e dal server. '
                'Non possiamo però impedire che venga fotografato con un altro '
                'dispositivo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🚨 La foto effimera si scarica in `Cache/foto/effimere/` — N16.6.
///
/// ⚠️ È ciò che la tiene **fuori dal backup per costruzione**: Android esclude
/// sempre `getCacheDir()` e quell'esclusione non è sovrascrivibile. Una foto
/// «una volta sola» finita su Drive ci resterebbe per sempre — l'esatto
/// contrario di quello che ha chiesto chi l'ha mandata, e nessuno se ne
/// accorgerebbe.
final _fotoEffimeraProvider = FutureProvider.autoDispose
    .family<String?, ContenutoFoto>((ref, busta) async {
      return AllegatoDiChat(
        api: ref.watch(apiClientProvider),
        cripto: CifraturaAllegati(await ref.watch(sodiumProvider.future)),
      ).riprendi(busta, dove: TipoFoto.effimere);
    });

class _FotoEffimera extends ConsumerWidget {
  const _FotoEffimera({required this.busta});

  final ContenutoFoto busta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(_fotoEffimeraProvider(busta))
        .when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: Text(
              'Non riesco ad aprire questa foto.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          data: (relativo) {
            if (relativo == null) {
              // 💡 Non è un guasto: è scaduta, o l'ha già presa un altro
              // dispositivo. Va detto così.
              return const Padding(
                padding: EdgeInsets.all(Gap.lg),
                child: Text(
                  'Questa foto non c\'è più.',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            return FutureBuilder<File>(
              future: const ArchivioFoto().fileDi(relativo),
              builder: (_, esito) => esito.hasData
                  ? InteractiveViewer(child: Image.file(esito.data!))
                  : const CircularProgressIndicator(),
            );
          },
        );
  }
}

/// La traccia di ciò che non c'è più — N16.4b.
///
/// 🚨 **Non è un errore.** Il messaggio ha fatto esattamente quello che chi
/// l'ha mandato ha chiesto. Una riga sparita farebbe pensare a un guasto; una
/// che dice «Foto effimera» dice cos'è successo.
class UsaEGettaSpenta extends StatelessWidget {
  const UsaEGettaSpenta({
    required this.messaggio,
    required this.mio,
    super.key,
  });

  final ChatMessage messaggio;
  final bool mio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Gap.radius),
          border: Border.all(color: tema.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              size: 16,
              color: tema.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Gap.xs),
            Text(
              messaggio.body,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
