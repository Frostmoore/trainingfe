import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// 🃏 **Una voce del profilo, come carta** — `plan_interfaccia.md` I7,
/// 19/11/2026.
///
/// 📌 Tavola «Profilo»: le voci sono carte con l'icona in un quadratino
/// colorato; **le corte a coppie, le lunghe a tutta larghezza** (I7.D2).
///
/// 💡 **Due forme dallo stesso widget**, scelte da [larga]:
/// - `larga: true` (il default) — riga: icona, titolo e sottotitolo, freccia;
/// - `larga: false` — colonna, per stare in una `Coppia`: icona sopra, titolo
///   e sottotitolo sotto. ⚠️ Senza freccia: in mezza larghezza ruberebbe
///   spazio al titolo, e la carta intera si capisce da sola che si tocca.
///
/// 🟠 [avviso] colora sottotitolo e quadratino in arancio: è il segnale di
/// «Backup e dati» quando il backup automatico è spento (I7.D3). ⚠️ Arancio e
/// non rosso: non è un errore, è una cosa da sapere.
///
/// 🎨 [piena] riempie la carta col colore primario (la tavola lo usa per
/// «Offerte per te»): è la sola voce che invita, non che configura.
class VoceDelProfilo extends StatelessWidget {
  const VoceDelProfilo({
    required this.icona,
    required this.titolo,
    this.sottotitolo,
    this.onTap,
    this.larga = true,
    this.avviso = false,
    this.piena = false,
    this.coda,
    super.key,
  });

  final IconData icona;
  final String titolo;
  final String? sottotitolo;
  final VoidCallback? onTap;

  /// `true`: a tutta larghezza, in riga. `false`: in colonna, per una coppia.
  final bool larga;

  /// Sottotitolo e icona in arancio.
  final bool avviso;

  /// Carta piena del colore primario.
  final bool piena;

  /// Al posto della freccia, nella forma larga (per esempio «Mostra»).
  final Widget? coda;

  /// L'arancio dell'avviso, in chiaro e in scuro.
  ///
  /// ⚠️ Due toni: quello scuro su fondo chiaro, quello chiaro su fondo scuro;
  /// uno solo sparirebbe in uno dei due temi.
  static Color arancio(Brightness luce) => luce == Brightness.dark
      ? const Color(0xFFFDBA8C)
      : const Color(0xFF9A3412);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final schema = tema.colorScheme;
    final colArancio = arancio(tema.brightness);

    final primo = piena ? schema.onPrimary : schema.onSurface;
    final secondo = avviso
        ? colArancio
        : piena
        ? schema.onPrimary.withValues(alpha: 0.9)
        : schema.onSurfaceVariant;

    final quadratino = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: piena
            ? schema.onPrimary.withValues(alpha: 0.18)
            : avviso
            ? colArancio.withValues(alpha: 0.14)
            : schema.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icona,
        size: 20,
        color: piena
            ? schema.onPrimary
            : avviso
            ? colArancio
            : schema.primary,
      ),
    );

    final testi = <Widget>[
      Text(
        titolo,
        style: tema.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: primo,
        ),
      ),
      if (sottotitolo != null)
        Text(
          sottotitolo!,
          style: tema.textTheme.bodySmall?.copyWith(
            color: secondo,
            fontWeight: avviso ? FontWeight.w600 : null,
          ),
        ),
    ];

    final contenuto = larga
        ? Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: 14,
            ),
            child: Row(
              children: [
                quadratino,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: testi,
                  ),
                ),
                if (coda != null)
                  coda!
                else if (onTap != null)
                  Icon(Icons.chevron_right_rounded, color: secondo),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [quadratino, const SizedBox(height: 10), ...testi],
            ),
          );

    return Card(
      margin: EdgeInsets.zero,
      color: piena ? schema.primary : null,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? contenuto
          : InkWell(onTap: onTap, child: contenuto),
    );
  }
}
