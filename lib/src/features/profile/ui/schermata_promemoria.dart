import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/il_giro_dei_promemoria.dart';
import '../../../core/notifications/notifications.dart';
import '../../../core/notifications/preferenze_dei_promemoria.dart';
import '../../../core/ui/intestazione_app.dart';

/// ⏰ **«Promemoria»** — voce 62, 27/09/2026.
///
/// ══ 📌 PERCHE' QUESTA SCHERMATA ESISTE ════════════════════════════════════
///
/// 📌 Il committente: *«implementale tutte subito»*, parlando delle notifiche del
/// catalogo. 💡 Le quattro locali sono promemoria, e un promemoria senza
/// interruttore è una notifica che si spegne **dalle impostazioni di sistema** —
/// dove si spengono **tutte**, comprese quelle che servivano.
///
/// ══ 🔑 PERCHE' STA NEL PROFILO E NON NELLE NOTIFICHE DI SISTEMA ═══════════
///
/// ⚖️ Qui si scelgono **quali** promemoria e a che ora; il permesso di mostrare
/// notifiche lo dà il sistema operativo. ⛔ Sono due cose diverse, e confonderle
/// è il motivo per cui tante app hanno un interruttore che non fa niente perché
/// il permesso non c'è.
///
/// 💡 Per questo, se il permesso manca, questa schermata **lo dice** e offre di
/// chiederlo: ⚠️ senza, una persona accenderebbe quattro interruttori e non
/// riceverebbe niente, convinta di averli accesi.
///
/// ══ ⚠️ SI SALVA SUBITO, SENZA PULSANTE «SALVA» ════════════════════════════
///
/// 🚨 Ogni tocco scrive e **riprogramma**. ⛔ Con un pulsante «salva», chi spegne
/// un promemoria e torna indietro continuerebbe a riceverlo per una settimana —
/// e sarebbe convinto di averlo spento, che è il modo più rapido per fargli
/// spegnere tutto dal sistema.
class SchermataPromemoria extends ConsumerStatefulWidget {
  const SchermataPromemoria({super.key});

  @override
  ConsumerState<SchermataPromemoria> createState() =>
      _SchermataPromemoriaState();
}

class _SchermataPromemoriaState extends ConsumerState<SchermataPromemoria> {
  PreferenzeDeiPromemoria? _preferenze;

  /// `null` finché non lo si è chiesto al sistema.
  bool? _permesso;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final lette = await ArchivioDeiPromemoria.leggi();
    final consentite = await notificheConsentite();

    if (!mounted) return;

    setState(() {
      _preferenze = lette;
      _permesso = consentite;
    });
  }

  /// 💾 Salva e riprogramma, in quest'ordine.
  ///
  /// ⚠️ **Prima si scrive, poi si riprogramma**: 🚨 `IlGiroDeiPromemoria.rifai()`
  /// rilegge le preferenze dal telefono, quindi riprogrammare prima di aver
  /// scritto rimetterebbe in piedi quelli vecchi.
  Future<void> _salva(PreferenzeDeiPromemoria nuove) async {
    setState(() => _preferenze = nuove);

    await ArchivioDeiPromemoria.scrivi(nuove);
    await ref.read(giroDeiPromemoriaProvider).rifai();
  }

  @override
  Widget build(BuildContext context) {
    final p = _preferenze;

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Promemoria'),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                const _Cappello(),

                if (_permesso == false) _IlPermessoManca(onChiedi: _chiedi),

                _UnPromemoria(
                  icona: Icons.fitness_center_outlined,
                  titolo: 'Allenamento',
                  spiegazione:
                      'Un richiamo se non ti sei allenato. Il testo cambia con i giorni passati.',
                  acceso: p.allenamento,
                  ora: p.oraAllenamento,
                  onAcceso: (v) => _salva(p.copyWith(allenamento: v)),
                  onOra: (v) => _salva(p.copyWith(oraAllenamento: v)),
                ),

                _UnPromemoria(
                  icona: Icons.restaurant_outlined,
                  titolo: 'Diario alimentare',
                  spiegazione:
                      'La sera, se non hai segnato niente durante la giornata.',
                  acceso: p.diario,
                  ora: p.oraDiario,
                  onAcceso: (v) => _salva(p.copyWith(diario: v)),
                  onOra: (v) => _salva(p.copyWith(oraDiario: v)),
                ),

                _UnPromemoria(
                  icona: Icons.monitor_weight_outlined,
                  titolo: 'Peso e misure',
                  spiegazione:
                      'Una volta a settimana. Di mattina, a digiuno: è l\'unico modo per cui due pesate si possano confrontare.',
                  acceso: p.misure,
                  ora: p.oraMisure,
                  onAcceso: (v) => _salva(p.copyWith(misure: v)),
                  onOra: (v) => _salva(p.copyWith(oraMisure: v)),
                  giorno: p.giornoMisure,
                  onGiorno: (v) => _salva(p.copyWith(giornoMisure: v)),
                ),

                const _PerchePassanoDaQui(),
              ],
            ),
    );
  }

  Future<void> _chiedi() async {
    final dato = await requestNotificationPermission();

    if (!mounted) return;

    setState(() => _permesso = dato);

    if (dato) await ref.read(giroDeiPromemoriaProvider).rifai();
  }
}

class _Cappello extends StatelessWidget {
  const _Cappello();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Text(
      'Questi promemoria li prepara il telefono, non il server: '
      'per farli funzionare non serve la rete e non escono da qui.',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// 🚨 Il permesso manca: senza, gli interruttori non fanno niente.
class _IlPermessoManca extends StatelessWidget {
  const _IlPermessoManca({required this.onChiedi});

  final Future<void> Function() onChiedi;

  @override
  Widget build(BuildContext context) {
    final colori = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colori.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_off_outlined, color: colori.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Il telefono non ha il permesso di mostrare notifiche: '
              'finché manca, questi promemoria non arrivano.',
              style: TextStyle(color: colori.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onChiedi, child: const Text('Consenti')),
        ],
      ),
    );
  }
}

/// 📝 Una riga: interruttore, e quando è acceso l'ora (e il giorno, se serve).
class _UnPromemoria extends StatelessWidget {
  const _UnPromemoria({
    required this.icona,
    required this.titolo,
    required this.spiegazione,
    required this.acceso,
    required this.onAcceso,
    this.ora,
    this.onOra,
    this.giorno,
    this.onGiorno,
  });

  final IconData icona;
  final String titolo;
  final String spiegazione;
  final bool acceso;
  final ValueChanged<bool> onAcceso;

  /// `null` per «scheda finita», che è un evento e non ha un'ora.
  final TimeOfDay? ora;
  final ValueChanged<TimeOfDay>? onOra;

  final int? giorno;
  final ValueChanged<int>? onGiorno;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          value: acceso,
          onChanged: onAcceso,
          secondary: Icon(icona),
          title: Text(titolo),
          subtitle: Text(spiegazione, style: testo.bodySmall),
          isThreeLine: true,
        ),

        /*
         * 💡 L'ora compare **solo se il promemoria è acceso**: ⛔ un selettore
         * d'ora sotto un interruttore spento è una domanda a cui non serve
         * rispondere, e fa sembrare che spegnere non abbia funzionato.
         */
        if (acceso && ora != null)
          Padding(
            padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (giorno != null && onGiorno != null)
                  _ScegliIlGiorno(giorno: giorno!, onGiorno: onGiorno!),
                _ScegliLOra(ora: ora!, onOra: onOra!),
              ],
            ),
          ),

        const Divider(height: 1),
      ],
    );
  }
}

class _ScegliLOra extends StatelessWidget {
  const _ScegliLOra({required this.ora, required this.onOra});

  final TimeOfDay ora;
  final ValueChanged<TimeOfDay> onOra;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: const Icon(Icons.schedule, size: 18),
    label: Text(
      '${ora.hour.toString().padLeft(2, '0')}:'
      '${ora.minute.toString().padLeft(2, '0')}',
    ),
    onPressed: () async {
      final scelta = await showTimePicker(context: context, initialTime: ora);

      if (scelta != null) onOra(scelta);
    },
  );
}

/// 📆 Il giorno della settimana, per il promemoria settimanale.
class _ScegliIlGiorno extends StatelessWidget {
  const _ScegliIlGiorno({required this.giorno, required this.onGiorno});

  final int giorno;
  final ValueChanged<int> onGiorno;

  /// ⚠️ In italiano e scritti qui: 💡 `DateFormat.E` darebbe i nomi giusti ma
  /// dipende dal locale del telefono, e l'app parla italiano comunque.
  static const _nomi = {
    DateTime.monday: 'lunedì',
    DateTime.tuesday: 'martedì',
    DateTime.wednesday: 'mercoledì',
    DateTime.thursday: 'giovedì',
    DateTime.friday: 'venerdì',
    DateTime.saturday: 'sabato',
    DateTime.sunday: 'domenica',
  };

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    initialValue: giorno,
    onSelected: onGiorno,
    itemBuilder: (_) => [
      for (final v in _nomi.entries)
        PopupMenuItem(value: v.key, child: Text(v.value)),
    ],
    child: Chip(
      avatar: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(_nomi[giorno] ?? 'lunedì'),
    ),
  );
}

/// ⚖️ La nota in fondo: perché questi non passano dal server.
class _PerchePassanoDaQui extends StatelessWidget {
  const _PerchePassanoDaQui();

  @override
  Widget build(BuildContext context) {
    final colori = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 18, color: colori.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Il server non sa quando ti alleni, cosa mangi e quanto pesi: '
              'sono dati che stanno su questo telefono. Per questo i promemoria '
              'li prepara l\'app — e non passano da nessun servizio esterno.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colori.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
