import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// L'obiettivo di passi al giorno — 08/09/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// Il committente: *«ok che siano sotto a Bruciate, ma così sono troppo piccoli,
/// quasi invisibili. Mettici una bella barra che li conta a step in base al mio
/// obbiettivo (diciamo tra i 3000 e i 20000)»*.
///
/// ══ 💾 FINISCE NEL BACKUP DA SOLA ═════════════════════════════════════════
///
/// 🚨 `LocalCache` è `SharedPreferences`, e `PreferenzeNelBackup.esporta()` le
/// **enumera tutte**: questa chiave viaggia con la copia di sicurezza senza che
/// nessuno la aggiunga a un elenco. 💡 Ed è la proprietà giusta — è una scelta
/// della persona, non lo stato di uno schermo: chi cambia telefono si ritrova la
/// barra tarata come l'aveva lasciata.
///
/// ══ ⚠️ E NON C'ENTRA CON IL LIVELLO DI ATTIVITA' ══════════════════════════
///
/// ⛔ **Non si ricava da `LivelloAttivita.passiFinoA`, e non deve.** Quel numero
/// descrive la giornata che una persona **fa** — serve al fabbisogno calorico,
/// ed è per questo che `CalorieDalCammino.inEccesso` lo usa come tetto. Questo
/// descrive la giornata che una persona **vuole fare**.
///
/// 🚨 Sono due numeri che si somigliano e che qualcuno un giorno «uniforma»:
/// legarli vorrebbe dire che chi alza l'obiettivo si vede cambiare il
/// fabbisogno, o peggio che chi cammina di più si vede alzare l'obiettivo da
/// solo — cioè un traguardo che scappa via mentre lo raggiungi.
class ObiettivoPassi extends Notifier<int> {
  static const chiave = 'passi.obiettivo';

  /// ⚠️ **10.000 e non un numero ricavato dai suoi passi.** È il traguardo che
  /// tutti riconoscono, e chi non l'ha mai toccato deve trovare la barra tarata
  /// su qualcosa che sa già leggere.
  ///
  /// 💡 Sta comodo dentro l'intervallo chiesto (3.000–20.000) e non è un
  /// estremo: si può alzare e abbassare da subito.
  static const predefinito = 10000;

  /// 📌 Gli estremi chiesti dal committente: *«diciamo tra i 3000 e i 20000»*.
  static const minimo = 3000;
  static const massimo = 20000;

  /// Il gradino del selettore, in passi.
  ///
  /// 💡 Mille per volta: diciotto scatti da un estremo all'altro, che su un
  /// cursore si prendono senza mirare. ⛔ Cento per volta darebbe un cursore
  /// impossibile e una precisione che su un obiettivo non vuol dire niente.
  static const passo = 1000;

  /// Entro gli estremi, sempre.
  ///
  /// 🚨 **Si applica anche in lettura, non solo in scrittura.** Un valore fuori
  /// scala può arrivare da un backup vecchio o da una versione futura che allarga
  /// l'intervallo: senza questo, la barra si disegnerebbe su un fondo che non
  /// esiste — e nessuno saprebbe da dove viene.
  static int entroIlimiti(int valore) => valore.clamp(minimo, massimo);

  @override
  int build() {
    final salvato = ref.watch(localCacheProvider).getInt(chiave);

    return salvato == null ? predefinito : entroIlimiti(salvato);
  }

  Future<void> scegli(int passi) async {
    final valore = entroIlimiti(passi);

    state = valore;

    await ref.read(localCacheProvider).setInt(chiave, value: valore);
  }
}

final obiettivoPassiProvider = NotifierProvider<ObiettivoPassi, int>(
  ObiettivoPassi.new,
);
