/// L'intestazione di un allenamento — 3b-C.4, 25/08/2026.
///
/// 📌 *«deve essere IDENTICA. Stesse cards, stesso layout, stessi numeri, stesse
/// cose»*.
///
/// ⛔ Le due pagine cominciavano in due modi diversi: quella di una seduta con
/// **titolo e data**, quella del polso con **icona, tipo e data**. Due prime
/// righe diverse bastano a far sembrare due schermate quelle che devono essere
/// una — è la prima cosa che si guarda.
///
/// 💡 Una sola, che prende il nome da dove ce n'è uno: la scheda associata, il
/// titolo della seduta, o il tipo di sport.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../health/tipo_allenamento.dart';
import '../../data/storico_unificato.dart';

class TestaDellAllenamento extends StatelessWidget {
  const TestaDellAllenamento({required this.voce, super.key});

  final VoceStorico voce;

  /// Come si chiama questo allenamento.
  ///
  /// 🚨 **La scheda vince su tutto**, quando c'è: *«Giorno 1»* dice più di
  /// «Pesi», e se l'hai associata tu è la risposta che hai dato.
  String get _titolo {
    final scheda = voce.nomeScheda;

    if (scheda != null && scheda.trim().isNotEmpty) return scheda;

    final seduta = voce.seduta;

    if (seduta != null && seduta.titolo.trim().isNotEmpty) return seduta.titolo;

    final tipo = voce.tipo;

    return tipo == null ? 'Allenamento' : TipoAllenamento.da(tipo).nome;
  }

  /// 💡 Il manubrio per le sedute nate nell'app: lì il tipo non esiste, e
  /// inventarne uno sarebbe la deduzione che B.9 ha vietato.
  IconData get _icona {
    final tipo = voce.tipo;

    return tipo == null ? Icons.fitness_center : TipoAllenamento.da(tipo).icona;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      children: [
        Icon(_icona, size: 32, color: tema.colorScheme.primary),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_titolo, style: tema.textTheme.titleLarge),
              Text(
                DateFormat('EEEE d MMMM, HH:mm', 'it').format(voce.quando),
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
