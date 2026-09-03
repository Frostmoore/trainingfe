/// La barra che tiene l'originale a un tocco — Parte K, K4.
///
/// ══ 📌 PERCHE' UNA BARRA E NON UN PULSANTE ════════════════════════════════
///
/// 📌 Il committente, il 03/09/2026: *«un tasto in basso a sx per vedere il
/// documento originale»*.
///
/// ⛔ **Non un `FloatingActionButton` che scorre via.** Il confronto si fa
/// **riga per riga**, e un pulsante che sparisce quando si scorre costringe a
/// tornare in cima trenta volte — cioè fa smettere di confrontare dopo la
/// quinta.
///
/// 🚨 E il rischio di questo import non è che l'AI **fallisca**: un fallimento
/// si vede e si rifà. È che riesca **a metà** — «200 g» letti «20 g» non danno
/// nessun errore, danno un piano plausibile e sbagliato. 💡 L'unica cosa che lo
/// scopre è l'originale accanto.
library;

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/theme/app_theme.dart';
import '../data/origine_della_bozza.dart';

class BarraDelDocumento extends StatelessWidget {
  const BarraDelDocumento({required this.origine, super.key});

  final OrigineDellaBozza origine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.sm,
            vertical: Gap.xs,
          ),
          child: Row(
            children: [
              /*
               * 📌 **A sinistra, come chiesto.** ⚠️ E con l'etichetta scritta,
               * non solo l'icona: un'icona di documento accanto a una bozza si
               * legge come «allega», non come «guarda quello vero».
               */
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _apri(context),
                    icon: Icon(
                      origine.daFotografia
                          ? Icons.image_outlined
                          : Icons.picture_as_pdf_outlined,
                    ),
                    label: Text(
                      origine.documenti.length > 1
                          ? 'Originale (${origine.documenti.length})'
                          : 'Vedi l\'originale',
                    ),
                  ),
                ),
              ),

              /*
               * 💡 **Quante righe ci sono da controllare, sempre visibile.**
               *
               * 🚨 «34 righe da confrontare» è un'informazione che cambia come
               * qualcuno affronta la revisione: chi crede che sia questione di
               * due secondi la fa male. ⚠️ Detta una volta in cima si dimentica;
               * qui resta.
               */
              Text(
                '${origine.righeDaControllare} '
                '${origine.righeDaControllare == 1 ? "riga" : "righe"} da controllare',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: Gap.xs),
            ],
          ),
        ),
      ),
    );
  }

  /// Apre il documento con l'applicazione del telefono.
  ///
  /// ⚠️ **Con più pagine si apre la prima**, e le altre si scelgono da un
  /// foglio: aprirle tutte insieme vorrebbe dire cinque applicazioni sovrapposte
  /// e nessun modo di tornare indietro.
  Future<void> _apri(BuildContext context) async {
    if (origine.documenti.isEmpty) return;

    if (origine.documenti.length == 1) {
      await OpenFilex.open(origine.documenti.first);

      return;
    }

    final quale = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(Gap.md),
              child: Text('Quale pagina?'),
            ),
            for (final (i, percorso) in origine.documenti.indexed)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text('Pagina ${i + 1}'),
                onTap: () => Navigator.of(context).pop(percorso),
              ),
          ],
        ),
      ),
    );

    if (quale != null) await OpenFilex.open(quale);
  }
}
