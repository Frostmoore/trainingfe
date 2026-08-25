/// La spunta che dice «questa serie l'ho fatta» — 3b-E.2, 25/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«Il segno di spunta per marcare la serie come completata dovrebbe essere più
/// piccolo e più carino»*.
///
/// ══ 🚨 PICCOLO SÌ, MA NON PIÙ PICCOLO DEL DITO ════════════════════════════
///
/// ⛔ Il tondo disegnato è **28 px**, ma l'area che risponde al tocco è di
/// **40×40**: sotto quella misura un bersaglio si manca, e questo si preme in
/// piedi, con le mani sudate, con il telefono appoggiato sulla panca. 💡 Un
/// `Center` dentro un `SizedBox` più grande costa niente e non si vede.
///
/// ⚠️ **Non torna indietro.** Ripremerla **riscrive** la serie con i numeri che
/// ci sono adesso — la scrittura è un upsert — e questo è voluto: correggere un
/// peso appena registrato capita di continuo, e togliere una serie già fatta
/// quasi mai. 💡 Per dire che la riscrittura è avvenuta c'è la pulsazione:
/// senza, ripremere sembrerebbe non fare niente.
library;

import 'package:flutter/material.dart';

class SpuntaDellaSerie extends StatefulWidget {
  const SpuntaDellaSerie({
    required this.fatta,
    required this.onTocco,
    super.key,
  });

  final bool fatta;
  final VoidCallback onTocco;

  @override
  State<SpuntaDellaSerie> createState() => _SpuntaDellaSerieState();
}

class _SpuntaDellaSerieState extends State<SpuntaDellaSerie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulsazione = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    lowerBound: 0.86,
    upperBound: 1,
    value: 1,
  );

  @override
  void dispose() {
    _pulsazione.dispose();
    super.dispose();
  }

  void _premuta() {
    _pulsazione
      ..value = 0.86
      ..forward();

    widget.onTocco();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final fatta = widget.fatta;

    return Semantics(
      button: true,
      selected: fatta,
      label: fatta ? 'Serie fatta' : 'Segna la serie come fatta',
      child: InkResponse(
        onTap: _premuta,
        radius: 22,
        child: SizedBox(
          // 🚨 Il bersaglio, non il disegno: vedi la nota in cima.
          width: 40,
          height: 40,
          child: Center(
            child: ScaleTransition(
              scale: _pulsazione,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fatta ? tema.colorScheme.primary : Colors.transparent,
                  border: Border.all(
                    color: fatta
                        ? tema.colorScheme.primary
                        : tema.colorScheme.outlineVariant,
                    width: 1.6,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 18,
                  /*
                   * 💡 La spunta c'è **anche da spenta**, sbiadita: dice cosa
                   * succede toccando, invece di lasciare un cerchio muto. ⚠️ Un
                   * bersaglio vuoto in mezzo a tre campi numerici si legge come
                   * un campo in più, non come un pulsante.
                   */
                  color: fatta
                      ? tema.colorScheme.onPrimary
                      : tema.colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
