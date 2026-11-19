import 'package:flutter/material.dart';

/// ‹ **La data con le frecce, una sola per tutta l'app** —
/// `plan_interfaccia.md` §3.4, I1, 19/11/2026.
///
/// ══ 🚨 PERCHÉ NASCE ═══════════════════════════════════════════════════════
///
/// Oggi (`_BarraData`), Diario (`_BarraGiorno`) e Allenamento
/// (`BarraSettimana`) avevano **tre** navigatori diversi per lo stesso gesto.
/// Nelle testate scure stanno tutti nello stesso posto, e devono essere lo
/// stesso oggetto.
///
/// ⚠️ **Si unifica il disegno, non lo stato.** Ognuno resta col suo provider
/// (`giornoSceltoProvider`, `selectedDateProvider`, `settimanaSceltaProvider`)
/// e passa qui solo il testo e i tre gesti. ⛔ Unificare lo stato vorrebbe dire
/// che cambiare giorno in Oggi cambia anche il Diario: un comportamento nuovo
/// che nessuno ha chiesto.
///
/// ══ ⛔ LA FRECCIA AVANTI SI SPEGNE SU OGGI ═════════════════════════════════
///
/// Regola 3b-O.1b.2: una giornata che non è ancora successa non ha calorie,
/// peso né sonno, e portarci vorrebbe dire una schermata vuota che sembra un
/// guasto. Qui la regola diventa: [onDopo] `null` = freccia spenta, **e si
/// vede** che è spenta.
///
/// 💡 Toccare il testo riporta a oggi in un colpo ([onTesto]), invece di
/// premere la freccia tante volte quanti sono i giorni indietro.
class BarraDellaData extends StatelessWidget {
  const BarraDellaData({
    required this.testo,
    required this.onPrima,
    this.onDopo,
    this.onTesto,
    this.etichettaPrima = 'Giorno prima',
    this.etichettaDopo = 'Giorno dopo',
    super.key,
  });

  /// «Mercoledì 19 novembre», «17 – 23 nov · 2 sedute».
  final String testo;

  final VoidCallback onPrima;

  /// `null` = si è su oggi, e avanti non si va.
  final VoidCallback? onDopo;

  /// `null` = il testo non si tocca (si è già su oggi).
  final VoidCallback? onTesto;

  /// I suggerimenti delle frecce: «Settimana prima» nello storico.
  final String etichettaPrima;

  final String etichettaDopo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colore = theme.colorScheme.onSurface;

    return Row(
      children: [
        IconButton(
          onPressed: onPrima,
          icon: Icon(Icons.chevron_left_rounded, color: colore),
          tooltip: etichettaPrima,
        ),

        Expanded(
          child: GestureDetector(
            onTap: onTesto,
            child: Text(
              testo,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colore,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        IconButton(
          onPressed: onDopo,
          icon: Icon(
            Icons.chevron_right_rounded,
            // ⚠️ `null` spegne già il pulsante, ma su fondo scuro il grigio
            // di serie si confonde: lo si attenua a mano, così si **vede**.
            color: onDopo == null ? colore.withValues(alpha: 0.3) : colore,
          ),
          tooltip: etichettaDopo,
        ),
      ],
    );
  }
}
