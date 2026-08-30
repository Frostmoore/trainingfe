/// Cosa si può concludere dalla composizione corporea — 3b-Y, 30/08/2026.
///
/// ══ 🎯 LA DOMANDA CHE VALE ════════════════════════════════════════════════
///
/// Non «quanto peso», che lo dice già la scheda del peso. Ma **cosa** ho perso:
/// due chili di grasso e due chili di muscolo pesano uguale sulla bilancia e
/// sono l'opposto l'uno dell'altro.
///
/// 🚨 È l'unica conclusione che la massa grassa permette e il peso da solo no,
/// ed è il motivo per cui 3b-W esisteva.
///
/// ══ ⛔ QUANDO NON SI CONCLUDE NIENTE, SI DICE ═════════════════════════════
///
/// ⚠️ Una bilancia a bioimpedenza sbaglia di qualche punto, e su 95 kg **un
/// punto è quasi un chilo**. Un confronto fra ieri e oggi non misura il corpo:
/// misura l'idratazione.
///
/// 💡 Per questo servono [giorniMinimi] di distanza e un cambiamento più grande
/// del rumore ([sogliaKg]) — e sotto quella soglia la risposta è *«non è ancora
/// cambiato abbastanza»*, che è una risposta vera e non un silenzio.
library;

import '../../core/storage/archivio_salute.dart';

/// Com'è fatto un corpo, in chili.
class Composizione {
  const Composizione({
    required this.pesoKg,
    required this.grassoKg,
    required this.magraKg,
    required this.grassoPct,
  });

  final double pesoKg;
  final double grassoKg;
  final double magraKg;
  final double grassoPct;
}

/// Cosa è successo fra due momenti.
enum Verdetto {
  /// 🎯 Grasso giù, muscolo tenuto. È il risultato che si cerca.
  grassoGiuMuscoloTenuto,

  /// ⚠️ Si dimagrisce, ma se ne va anche la massa magra.
  giuAncheIlMuscolo,

  /// 💪 Peso su, e in buona parte è muscolo.
  suSoprattuttoMuscolo,

  /// ⚠️ Il peso in più è grasso.
  suSoprattuttoGrasso,

  /// Niente si è mosso abbastanza da poterlo dire.
  fermo,
}

/// La lettura della composizione: adesso, prima, e cosa è cambiato.
class LetturaDellaComposizione {
  const LetturaDellaComposizione({
    required this.adesso,
    this.prima,
    this.giorni,
    this.verdetto,
  });

  final Composizione adesso;

  /// `null` quando non c'è ancora abbastanza storia per un confronto.
  final Composizione? prima;

  /// Quanti giorni separano i due momenti.
  final int? giorni;

  /// `null` quando non c'è [prima].
  final Verdetto? verdetto;

  double? get deltaGrassoKg =>
      prima == null ? null : adesso.grassoKg - prima!.grassoKg;

  double? get deltaMagraKg =>
      prima == null ? null : adesso.magraKg - prima!.magraKg;

  double? get deltaPesoKg =>
      prima == null ? null : adesso.pesoKg - prima!.pesoKg;
}

/// Quanti giorni devono passare perché un confronto voglia dire qualcosa.
///
/// 🚨 **Ventuno, e non sette.** Il grasso corporeo si muove di poche centinaia
/// di grammi a settimana anche con un deficit serio: su una settimana la
/// differenza vera è più piccola dell'errore della bilancia, e quello che si
/// leggerebbe sarebbe rumore travestito da progresso.
///
/// ⛔ E leggere il rumore come progresso è peggio che non leggere niente: la
/// settimana dopo il numero torna indietro, e sembra di aver sbagliato tutto.
const giorniMinimi = 21;

/// Sotto quanti chili di scostamento non si conclude niente.
///
/// ⚠️ **Ottocento grammi**, e viene dall'errore della misura, non da una scelta
/// estetica: una bilancia a bioimpedenza sbaglia di qualche punto percentuale, e
/// su un corpo da 95 kg **un punto è quasi un chilo**.
///
/// 💡 Sotto questa soglia il verdetto è [Verdetto.fermo] — che non vuol dire
/// «non stai facendo niente», vuol dire «non lo so ancora».
const sogliaKg = 0.8;

/// Su quanti giorni si media ciascuno dei due estremi.
///
/// 💡 Mediare toglie il rumore della singola pesata: 96,15 kg alle 17:48 e 95,85
/// alle 18:08 dello stesso giorno sono trecento grammi che non sono grasso.
const finestraDiMedia = 7;

/// Legge la composizione dallo storico. `null` se non se ne può dire niente.
///
/// ══ 🚨 IL PESO E LA MASSA GRASSA SI MEDIANO SEPARATAMENTE ════════════════
///
/// ⚠️ Possono arrivare da giorni diversi — chi si pesa ogni giorno e misura il
/// grasso una volta a settimana — quindi **non** si cercano righe che abbiano
/// tutti e due i valori: si fa la media di ciascuno sulla sua finestra.
///
/// ⛔ Pretendere la coppia sulla stessa riga butterebbe via quasi tutto lo
/// storico di chi ha una bilancia che misura il grasso di rado.
///
/// @param storico dal **più recente** al più vecchio
LetturaDellaComposizione? leggiLaComposizione({
  required List<MisuraCorpo> storico,
  DateTime? adesso,
}) {
  if (storico.isEmpty) return null;

  final oggi = adesso ?? DateTime.now();

  final ora = _composizioneIntorno(storico, oggi, 0);

  // ⛔ Senza peso o senza grasso non c'è nessuna composizione da mostrare.
  if (ora == null) return null;

  /*
   * ⏳ Il confronto: la finestra di [giorniMinimi] fa. ⚠️ Se non c'è, si torna
   * **solo la fotografia di adesso** — che è già un dato vero — e chi disegna
   * dirà che per la conclusione serve ancora tempo.
   */
  final prima = _composizioneIntorno(storico, oggi, giorniMinimi);

  if (prima == null) return LetturaDellaComposizione(adesso: ora);

  const giorni = giorniMinimi;
  final dGrasso = ora.grassoKg - prima.grassoKg;
  final dMagra = ora.magraKg - prima.magraKg;

  return LetturaDellaComposizione(
    adesso: ora,
    prima: prima,
    giorni: giorni,
    verdetto: _verdetto(dGrasso: dGrasso, dMagra: dMagra),
  );
}

/// 🚨 Il verdetto guarda **grasso e magra separatamente**, non il peso.
///
/// ⛔ Il peso da solo non distingue il caso migliore dal peggiore: −2 kg di
/// grasso e −2 kg di muscolo sulla bilancia sono lo stesso numero.
///
/// 💡 E il caso in cui il peso **non si muove affatto** è il più interessante:
/// grasso giù e muscolo su, che sulla bilancia non si vede per niente.
Verdetto _verdetto({required double dGrasso, required double dMagra}) {
  final grassoGiu = dGrasso <= -sogliaKg;
  final grassoSu = dGrasso >= sogliaKg;
  final magraGiu = dMagra <= -sogliaKg;
  final magraSu = dMagra >= sogliaKg;

  if (grassoGiu && magraGiu) return Verdetto.giuAncheIlMuscolo;
  if (grassoGiu) return Verdetto.grassoGiuMuscoloTenuto;

  if (grassoSu && magraSu) {
    /*
     * ⚠️ Quando salgono tutti e due, decide **chi è salito di più**: mettere su
     * due chili di cui uno e mezzo di muscolo è un'altra cosa dal contrario.
     */
    return dMagra >= dGrasso
        ? Verdetto.suSoprattuttoMuscolo
        : Verdetto.suSoprattuttoGrasso;
  }

  if (grassoSu) return Verdetto.suSoprattuttoGrasso;
  if (magraSu) return Verdetto.suSoprattuttoMuscolo;

  return Verdetto.fermo;
}

/// La composizione media in una finestra di giorni attorno a `giorniFa`.
Composizione? _composizioneIntorno(
  List<MisuraCorpo> storico,
  DateTime oggi,
  int giorniFa,
) {
  final centro = oggi.subtract(Duration(days: giorniFa));
  const meta = finestraDiMedia ~/ 2;

  bool dentro(DateTime g) {
    final d = centro.difference(g).inDays.abs();

    /*
     * ⚠️ Per «adesso» la finestra guarda **solo indietro**: una misura di
     * domani non esiste, e allargare in avanti non aggiunge niente. Per il
     * passato guarda da tutte e due le parti.
     */
    return giorniFa == 0
        ? !g.isAfter(centro) && centro.difference(g).inDays <= finestraDiMedia
        : d <= meta;
  }

  final pesi = <double>[];
  final grassi = <double>[];
  final magre = <double>[];

  for (final m in storico) {
    if (!dentro(m.giorno)) continue;

    if (m.pesoKg != null) pesi.add(m.pesoKg!);
    if (m.massaGrassaPct != null) grassi.add(m.massaGrassaPct!);
    if (m.massaMagraKg != null) magre.add(m.massaMagraKg!);
  }

  if (pesi.isEmpty) return null;

  final peso = _media(pesi);

  /*
   * 💡 **La massa magra misurata batte quella derivata**, come nel BMR: non
   * eredita l'errore della bioimpedenza sulla percentuale.
   */
  if (magre.isNotEmpty) {
    final magra = _media(magre);

    return Composizione(
      pesoKg: peso,
      magraKg: magra,
      grassoKg: peso - magra,
      grassoPct: (peso - magra) / peso * 100,
    );
  }

  if (grassi.isEmpty) return null;

  final pct = _media(grassi);

  /*
   * ⛔ Fuori dai limiti fisiologici non si corregge: si dice che non si sa. È la
   * stessa guardia di `CalcolatoreCalorie.massaMagraDa()`, e serve perché una
   * bilancia che non riesce a leggere l'impedenza scrive `0`.
   */
  if (pct < 2 || pct > 75) return null;

  final grasso = peso * pct / 100;

  return Composizione(
    pesoKg: peso,
    grassoKg: grasso,
    magraKg: peso - grasso,
    grassoPct: pct,
  );
}

double _media(List<double> v) => v.reduce((a, b) => a + b) / v.length;
