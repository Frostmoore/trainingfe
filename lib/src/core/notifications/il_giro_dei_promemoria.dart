import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/health/health_controller.dart';
import '../storage/archivio_salute.dart';
import 'i_promemoria.dart';
import 'preferenze_dei_promemoria.dart';

/// 🔄 **Chi va a prendere i fatti e fa riprogrammare** — voce 62, 27/09/2026.
///
/// ══ 📌 PERCHE' E' SEPARATO DA `IPromemoria` ═══════════════════════════════
///
/// 🔑 `IPromemoria` decide **se e quando** un promemoria serve, e lo fa su tre
/// date che gli si passano. ⚖️ Quella è la parte con le regole, e si prova con
/// tre date scritte a mano invece che con un database.
///
/// 💡 Qui invece c'è la parte noiosa: leggere le tre date dall'archivio e le
/// preferenze dal telefono. ⛔ Mescolarle vorrebbe dire che per provare «chi si è
/// allenato stamattina non riceve il promemoria» servirebbe un database aperto.
///
/// ══ ⚠️ QUANDO SI CHIAMA ═══════════════════════════════════════════════════
///
/// | Momento | Perché |
/// |---|---|
/// | all'apertura dell'app | 🔑 È il momento in cui si sa di più: i promemoria dei prossimi sette giorni si rifanno da zero |
/// | 🏋️ dopo una seduta finita | ⛔ Altrimenti alle 18 arriva «ci alleniamo?» a chi ha finito alle 17 |
/// | 🍎 dopo una voce di diario | Come sopra, per il promemoria della sera |
/// | ⚖️ dopo una pesata | Sposta il richiamo settimanale a sette giorni **da quella** |
/// | ⚙️ toccando un interruttore | ⛔ Senza, un promemoria spento continuerebbe a suonare per una settimana |
///
/// 🚨 **Non lancia mai.** Un promemoria che non si riesce a riprogrammare non
/// deve far fallire il salvataggio di una seduta: ⛔ sarebbe perdere
/// l'allenamento per non aver programmato un avviso.
class IlGiroDeiPromemoria {
  const IlGiroDeiPromemoria(this._archivio, this._promemoria);

  final ArchivioSalute _archivio;
  final IPromemoria _promemoria;

  /// 🔄 Legge i fatti e riprogramma tutto.
  Future<void> rifai() async {
    try {
      final preferenze = await ArchivioDeiPromemoria.leggi();

      final stato = StatoDeiPromemoria(
        ultimoAllenamento: await _archivio.ultimaSedutaFinita(),
        ultimaVoceDiario: await _archivio.ultimaScritturaDelDiario(),
        ultimaMisura: (await _archivio.ultimoPeso())?.giorno,
      );

      await _promemoria.riprogramma(stato: stato, preferenze: preferenze);
    } on Object catch (errore) {
      /*
       * ⚠️ Silenzio in produzione, e di proposito: 🚨 questo metodo viene
       * chiamato **dopo** che una seduta è stata salvata. ⛔ Lasciar passare
       * un'eccezione vorrebbe dire far sembrare fallito il salvataggio perché
       * non si è riusciti a programmare un avviso.
       */
      if (kDebugMode) debugPrint('Giro dei promemoria non fatto: $errore');
    }
  }

}

/// 🧩 Il giro, pronto da usare.
///
/// ⚠️ `FlutterLocalNotificationsPlugin()` si costruisce qui e non si tiene in
/// giro: 💡 il pacchetto è un singleton dietro le quinte, e ogni istanza parla
/// con lo stesso plugin — è la stessa cosa che fa `RestTimer`.
final giroDeiPromemoriaProvider = Provider<IlGiroDeiPromemoria>((ref) {
  return IlGiroDeiPromemoria(
    ref.read(archivioSaluteProvider),
    IPromemoria(IlPluginVero()),
  );
});
