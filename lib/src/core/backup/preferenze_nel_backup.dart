import 'package:shared_preferences/shared_preferences.dart';

/// Le preferenze dentro la copia di sicurezza — 22/08/2026.
///
/// ══ 🚨 IL BACKUP NON LE CONTENEVA, E I COMMENTI DICEVANO IL CONTRARIO ═════
///
/// 📌 Il committente, quando gliel'ho detto: *«ovviamente deve finire nel
/// backup. TUTTO deve finire nel backup […] te l'avevo già detto»*. E infatti
/// l'aveva già detto il 20/08: *«ogni volta che abbiamo un nuovo dato o un
/// nuovo file o qualsiasi altra cosa, questo deve comunque finire in qualche
/// modo nel backup»*.
///
/// ⚠️ Fino a oggi `BackupAutomatico` impaccava **l'archivio drift e le foto**, e
/// basta. 🚨 Quindi il colore d'accento, il consiglio nascosto e le sezioni
/// ripiegate del diario si perdevano a ogni ripristino — e
/// `colore_accento.dart` scriveva *«Sta in `LocalCache`, che finisce nella
/// copia di sicurezza come tutto il resto»*. ⛔ Un commento che mente è peggio
/// di nessun commento: chi lo legge mettendoci un dato vero lo perde.
///
/// ── 💡 Si enumera, non si elenca ─────────────────────────────────────────
///
/// 🚨 **Nessuna lista di chiavi da tenere aggiornata.** Si prendono **tutte**
/// le preferenze e si escludono le poche che non devono viaggiare: così una
/// preferenza nuova finisce nel backup **da sola**, che è la stessa proprietà
/// che fa funzionare `esportaPerBackup()` sulle tabelle.
///
/// ⚠️ L'elenco al contrario — «queste sì» — avrebbe funzionato oggi e sarebbe
/// diventato falso alla prossima riga scritta da qualcuno che non legge questo
/// file.
class PreferenzeNelBackup {
  const PreferenzeNelBackup._();

  /// Dove finiscono dentro la mappa dell'archivio.
  ///
  /// 💡 Va **dentro** l'archivio e non accanto: il formato del file di backup
  /// ha già i suoi campi, e cambiarlo vorrebbe dire che i file scritti finora
  /// non si aprono più. ⛔ `ripristinaDaBackup()` enumera le tabelle e ignora le
  /// chiavi che non conosce, quindi questa passa senza dare fastidio.
  static const chiave = '__preferenze__';

  /// Le preferenze che **restano su questo telefono**.
  ///
  /// ══ 🚨 NON SONO ESCLUSIONI DI COMODO ══════════════════════════════════
  ///
  /// | Chiave | Perché non viaggia |
  /// |---|---|
  /// | `sessione.ultima_persona` | ⛔ È l'id di chi ha usato **questo** telefono. Ripristinandolo da un altro, il controllo «è entrato qualcun altro?» crederebbe di sì e **svuoterebbe l'archivio appena ripristinato** |
  /// | `sessione.accoglienza_fatta` | Chi entra su un telefono nuovo deve rivedere consensi e ripristino |
  /// | `trasloco.allenamenti.fatto` | 🚨 Ripristinarlo su un'installazione pulita salterebbe il trasloco: gli allenamenti resterebbero sul server e il telefono non li avrebbe |
  /// | `gym.branding` | Una cache di rete, si rifà da sola in un secondo |
  /// | `backup_automatico_*` | Quando è stato fatto l'ultimo backup **di questo telefono**: ripristinarlo comprerebbe ventiquattro ore di silenzio a un telefono che non ne ha mai fatto uno |
  static const restanoQui = {
    'sessione.ultima_persona',
    'sessione.accoglienza_fatta',
    'trasloco.allenamenti.fatto',
    'gym.branding',
  };

  /// I prefissi che restano qui, per le famiglie di chiavi.
  ///
  /// ⚠️ `backup_automatico_` e non `backup.`: le due chiavi vere si chiamano
  /// `backup_automatico_ultimo_riuscito` e `backup_automatico_ultimo_errore`.
  /// 🚨 Un prefisso scritto a occhio non avrebbe escluso niente, e sarebbe
  /// stato invisibile — l'esclusione che non esclude è peggio di nessuna.
  static const prefissiCheRestanoQui = {'backup_automatico_'};

  /// Tutto quello che deve viaggiare, pronto per il JSON.
  ///
  /// ⚠️ I tipi si conservano: `SharedPreferences` distingue `int`, `bool`,
  /// `String` e `List<String>`, e riscrivere un `bool` come stringa vorrebbe
  /// dire una preferenza che al ripristino non si legge più.
  static Future<Map<String, dynamic>> esporta() async {
    final prefs = await SharedPreferences.getInstance();
    final fuori = <String, dynamic>{};

    for (final chiave in prefs.getKeys()) {
      if (_restaQui(chiave)) continue;

      final valore = prefs.get(chiave);
      if (valore == null) continue;

      fuori[chiave] = valore is List<String> ? {'_lista': valore} : valore;
    }

    return fuori;
  }

  /// Riscrive le preferenze da un backup.
  ///
  /// ⛔ **Non svuota niente prima.** Le preferenze di questo telefono che il
  /// backup non contiene restano: sono quelle di [restanoQui], e cancellarle
  /// vorrebbe dire far ripartire il trasloco o dimenticare chi era entrato.
  ///
  /// 💡 Non lancia mai: un ripristino che fallisce perché una preferenza ha un
  /// tipo strano sarebbe un archivio perso per un colore.
  static Future<void> ripristina(Object? dati) async {
    if (dati is! Map) return;

    final prefs = await SharedPreferences.getInstance();

    for (final voce in dati.entries) {
      final chiave = voce.key.toString();
      if (_restaQui(chiave)) continue;

      final valore = voce.value;

      try {
        switch (valore) {
          case final bool v:
            await prefs.setBool(chiave, v);
          case final int v:
            await prefs.setInt(chiave, v);
          case final double v:
            await prefs.setDouble(chiave, v);
          case final String v:
            await prefs.setString(chiave, v);
          case final Map<Object?, Object?> v when v['_lista'] is List:
            await prefs.setStringList(
              chiave,
              (v['_lista']! as List).map((e) => e.toString()).toList(),
            );
        }
      } on Object {
        // 💡 Una preferenza che non si riscrive non vale l'intero ripristino.
      }
    }
  }

  static bool _restaQui(String chiave) =>
      restanoQui.contains(chiave) ||
      prefissiCheRestanoQui.any(chiave.startsWith);
}
