import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalogo.dart';

/// ⏰ **Quando e se suonano i promemoria** — voce 62, 27/09/2026.
///
/// ══ 📌 PERCHE' SONO PREFERENZE E NON COSTANTI ═════════════════════════════
///
/// 📌 Il committente: *«implementale tutte subito»*, parlando delle notifiche
/// del catalogo.
///
/// 🚨 Un promemoria a un'ora che non va bene non è «un promemoria un po'
/// scomodo»: è il motivo per cui una persona spegne **tutte** le notifiche
/// dell'app dalle impostazioni di sistema — e da lì non si torna, perché nessuno
/// riapre quella schermata per riaccenderle.
///
/// 💡 Quindi ogni promemoria ha il suo interruttore e la sua ora, e i valori di
/// partenza sono scelti per essere **plausibili**, non perché qualcuno li abbia
/// chiesti: chi non li tocca non deve trovarsi il telefono che suona all'alba.
///
/// ══ ⚖️ LE SCELTE DI PARTENZA, E IL PERCHE' DI OGNUNA ══════════════════════
///
/// | Promemoria | Acceso | Quando | Perché così |
/// |---|---|---|---|
/// | 🏋️ allenamento | ✅ sì | 18:00 | ⚖️ Prima che la giornata sia finita ma dopo il lavoro: alle 20 «oggi tocca a te» è un rimprovero, non un promemoria |
/// | 🍎 diario | ✅ sì | 21:00 | 💡 Dopo cena: prima non si potrebbe segnarla, e la cena è il pasto che si dimentica |
/// | ⚖️ misure | ✅ sì | lunedì 9:00 | 💡 Settimanale e non giornaliera: pesarsi ogni giorno misura l'acqua, non i progressi. E di mattina, a digiuno, che è l'unico modo per cui due pesate si possano confrontare |
///
/// ⛔ **«Scheda finita» non c'è, e dal 28/09 non è più nemmeno nel catalogo.**
/// 📌 Il committente: *«Le schede non finiscono. Al massimo finisce
/// l'allenamento»*. 💡 Un interruttore per una notifica che non può scattare
/// sarebbe una promessa falsa in una schermata di impostazioni — e un caso in
/// catalogo che non si può implementare è un elenco che mente.
///
/// ══ 🚨 NIENTE DI QUESTO ESCE DAL TELEFONO ═════════════════════════════════
///
/// ⛔ Sono notifiche **locali**, e queste preferenze stanno in
/// `SharedPreferences`: 🔑 «a che ora ti alleni» e «quando ti pesi» sono dati
/// sulla salute e sulle abitudini, e il server non li chiede.
///
/// 💡 Finiscono nella copia di sicurezza da sole: `PreferenzeNelBackup` prende
/// **tutte** le chiavi tranne quelle in una lista di esclusione, e queste non ci
/// sono. ⚠️ Ed è giusto che viaggino: chi ripristina su un telefono nuovo si
/// ritrova i suoi orari, non i nostri.
@immutable
class PreferenzeDeiPromemoria {
  const PreferenzeDeiPromemoria({
    this.allenamento = true,
    this.oraAllenamento = const TimeOfDay(hour: 18, minute: 0),
    this.diario = true,
    this.oraDiario = const TimeOfDay(hour: 21, minute: 0),
    this.misure = true,
    this.oraMisure = const TimeOfDay(hour: 9, minute: 0),
    this.giornoMisure = DateTime.monday,
  });

  /// 🏋️ «Oggi tocca a te», «sono tre giorni che non ti alleni».
  final bool allenamento;
  final TimeOfDay oraAllenamento;

  /// 🍎 «Non hai segnato la cena».
  final bool diario;
  final TimeOfDay oraDiario;

  /// ⚖️ Peso e misure, una volta a settimana.
  final bool misure;
  final TimeOfDay oraMisure;

  /// Il giorno della settimana, come `DateTime.monday`…`DateTime.sunday`.
  final int giornoMisure;

  /// 🔑 Se un promemoria del catalogo è acceso.
  ///
  /// ⚠️ **Prende una `Notifica`, non una stringa**: ⛔ così non si può chiedere
  /// di un promemoria che non esiste, e aggiungendo una locale al catalogo il
  /// `switch` qui sotto smette di compilare — che è il modo di non dimenticarsi
  /// di darle un interruttore.
  bool acceso(Notifica quale) => switch (quale) {
    Notifica.promemoriaAllenamento => allenamento,
    Notifica.promemoriaDiario => diario,
    Notifica.promemoriaMisure => misure,

    /*
     * ⏱️ `fineRecupero` ha il suo interruttore dentro il player (`RestTimer`),
     * dove il contesto è chiaro: ⛔ metterlo anche qui vorrebbe dire due
     * interruttori per la stessa cosa, e chi ne trova due spenti in posti
     * diversi non capisce quale conta.
     */
    Notifica.fineRecupero => true,

    /*
     * 📡 Le push non si spengono da qui: le spegne il sistema operativo, e il
     * «non mandarmi offerte» sta sul server (voce 43). ⚠️ `true` e non un
     * lancio, perché questo metodo risponde a «suona?», e per una push la
     * risposta non dipende da queste preferenze.
     */
    _ => true,
  };

  PreferenzeDeiPromemoria copyWith({
    bool? allenamento,
    TimeOfDay? oraAllenamento,
    bool? diario,
    TimeOfDay? oraDiario,
    bool? misure,
    TimeOfDay? oraMisure,
    int? giornoMisure,
  }) => PreferenzeDeiPromemoria(
    allenamento: allenamento ?? this.allenamento,
    oraAllenamento: oraAllenamento ?? this.oraAllenamento,
    diario: diario ?? this.diario,
    oraDiario: oraDiario ?? this.oraDiario,
    misure: misure ?? this.misure,
    oraMisure: oraMisure ?? this.oraMisure,
    giornoMisure: giornoMisure ?? this.giornoMisure,
  );

  @override
  bool operator ==(Object other) =>
      other is PreferenzeDeiPromemoria &&
      other.allenamento == allenamento &&
      other.oraAllenamento == oraAllenamento &&
      other.diario == diario &&
      other.oraDiario == oraDiario &&
      other.misure == misure &&
      other.oraMisure == oraMisure &&
      other.giornoMisure == giornoMisure;

  @override
  int get hashCode => Object.hash(
    allenamento,
    oraAllenamento,
    diario,
    oraDiario,
    misure,
    oraMisure,
    giornoMisure,
  );
}

/// 💾 Legge e scrive le preferenze dei promemoria.
///
/// ⚠️ **Le chiavi hanno un prefisso `promemoria.`** e non nomi sciolti: 💡 così
/// si vedono insieme guardando le preferenze di un telefono, e non si
/// accavallano con niente.
class ArchivioDeiPromemoria {
  const ArchivioDeiPromemoria._();

  static const _acceso = 'promemoria.acceso.';
  static const _ora = 'promemoria.ora.';
  static const _giornoMisure = 'promemoria.giorno.misure';

  /// 📖 Le preferenze salvate, o quelle di partenza.
  ///
  /// 🚨 **Un errore di lettura restituisce i valori di partenza**, non un
  /// lancio: ⛔ un'app che non parte perché non riesce a leggere a che ora
  /// suonare un promemoria sarebbe sproporzionata.
  static Future<PreferenzeDeiPromemoria> leggi() async {
    try {
      final p = await SharedPreferences.getInstance();
      const d = PreferenzeDeiPromemoria();

      return PreferenzeDeiPromemoria(
        allenamento: p.getBool('${_acceso}allenamento') ?? d.allenamento,
        oraAllenamento:
            _oraDa(p.getString('${_ora}allenamento')) ?? d.oraAllenamento,
        diario: p.getBool('${_acceso}diario') ?? d.diario,
        oraDiario: _oraDa(p.getString('${_ora}diario')) ?? d.oraDiario,
        misure: p.getBool('${_acceso}misure') ?? d.misure,
        oraMisure: _oraDa(p.getString('${_ora}misure')) ?? d.oraMisure,
        giornoMisure: p.getInt(_giornoMisure) ?? d.giornoMisure,
      );
    } on Object {
      return const PreferenzeDeiPromemoria();
    }
  }

  static Future<void> scrivi(PreferenzeDeiPromemoria v) async {
    try {
      final p = await SharedPreferences.getInstance();

      await p.setBool('${_acceso}allenamento', v.allenamento);
      await p.setString('${_ora}allenamento', _testoDa(v.oraAllenamento));
      await p.setBool('${_acceso}diario', v.diario);
      await p.setString('${_ora}diario', _testoDa(v.oraDiario));
      await p.setBool('${_acceso}misure', v.misure);
      await p.setString('${_ora}misure', _testoDa(v.oraMisure));
      await p.setInt(_giornoMisure, v.giornoMisure);
    } on Object {
      // Silenzio voluto: le preferenze non salvate si riscrivono, e far
      // fallire il salvataggio di un'ora non aiuta nessuno.
    }
  }

  /// 🕐 `"18:00"` → `TimeOfDay`.
  ///
  /// ⚠️ **Si salva come testo `HH:mm` e non come minuti dalla mezzanotte**: 💡 un
  /// numero in un file di preferenze non si legge, `"18:00"` sì — e queste
  /// finiscono nel backup, che è un posto dove qualcuno guarderà.
  static TimeOfDay? _oraDa(String? testo) {
    if (testo == null) return null;

    final pezzi = testo.split(':');

    if (pezzi.length != 2) return null;

    final ore = int.tryParse(pezzi.first);
    final minuti = int.tryParse(pezzi.last);

    if (ore == null || minuti == null) return null;
    if (ore < 0 || ore > 23 || minuti < 0 || minuti > 59) return null;

    return TimeOfDay(hour: ore, minute: minuti);
  }

  static String _testoDa(TimeOfDay ora) =>
      '${ora.hour.toString().padLeft(2, '0')}:'
      '${ora.minute.toString().padLeft(2, '0')}';
}
