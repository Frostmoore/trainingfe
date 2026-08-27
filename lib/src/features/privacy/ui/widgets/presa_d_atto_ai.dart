/// ⚖️ Cosa l'AI non è — la presa d'atto obbligatoria, 3b-J.3, 27/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// 📌 *«tra i consensi mettiamo anche un consenso obbligatorio se vuoi attivare
/// l'ai che dice che "mi rendo conto che tutto ciò che è prodotto dall'ai non è
/// mai un consiglio medico, ma solo una stima stocastica generata da un modello
/// di intelligenza artificiale e che non devo farci alcun tipo di affidamento
/// perché ne va della mia vita e della mia salute"… l'importante è che chi
/// attiva l'ai legga questa cosa e vi acconsenta»*.
///
/// ══ 🚨 PERCHÉ UNA FINESTRA CHE BLOCCA, E NON UNA RIGA IN PIÙ ══════════════
///
/// ⛔ Una nota sotto l'interruttore la legge chi legge le note, cioè quasi
/// nessuno. 🚨 Qui il punto **non è informare**: è che chi accende sappia. E
/// l'unico modo di saperlo è fermarsi.
///
/// ⚠️ **La spunta è obbligatoria e parte spenta.** Un pulsante «Ho capito» da
/// solo si tocca per far sparire la finestra; una casella da spuntare richiede
/// un gesto in più che dichiara qualcosa — ed è quello che poi si conserva come
/// data.
///
/// ══ ⚠️ E NON BASTA QUESTA FINESTRA ════════════════════════════════════════
///
/// Il server **rifiuta** di accendere l'AI senza la presa d'atto
/// (`ai_disclaimer_required`): se la protezione vivesse solo qui, basterebbe una
/// chiamata all'API per saltarla — e sarebbe il percorso di chi poi si fa male.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Il testo, in prima persona.
///
/// 🚨 **In prima persona di proposito.** *«L'AI può sbagliare»* è
/// un'informazione su un prodotto; *«non devo farci affidamento»* è una cosa che
/// dico io. ⚠️ È la differenza fra leggere e dichiarare, ed è tutta la ragione
/// per cui questa schermata esiste.
///
/// 💡 È `const` e pubblica perché un test la controlla: sono le frasi che
/// spariscono per prime quando qualcuno trova la finestra «troppo lunga».
const testoPresaDAtto = [
  'Quello che l\'intelligenza artificiale produce in questa app — stime, '
      'consigli del giorno, analisi degli allenamenti — non è mai un parere '
      'medico, né un parere di un nutrizionista, né di un preparatore.',

  'È una stima statistica generata da un modello: costruisce la risposta più '
      'probabile, non quella vera. Può sbagliare, e può sbagliare mentre sembra '
      'sicura di sé.',

  'Non devo farci affidamento per decisioni che riguardano la mia salute, '
      'quello che mangio o come mi alleno. Se una cosa riguarda la mia salute, '
      'ne parlo con un medico.',

  'Ne va della mia vita e della mia salute, e me ne prendo la responsabilità.',
];

/// Mostra la presa d'atto. Torna `true` solo se è stata accettata davvero.
Future<bool> chiediLaPresaDAtto(BuildContext context) async {
  final accettata = await showDialog<bool>(
    context: context,

    // ⛔ **Non si chiude toccando fuori.** Chiudere per sbaglio una finestra che
    // si sta per accettare la farebbe riaprire; chiuderla per sbaglio quando
    // *non* si voleva accettare è invece il caso giusto — ma qui il gesto
    // ambiguo è l'unico che non deve esistere.
    barrierDismissible: false,
    builder: (_) => const _Finestra(),
  );

  return accettata ?? false;
}

class _Finestra extends StatefulWidget {
  const _Finestra();

  @override
  State<_Finestra> createState() => _FinestraState();
}

class _FinestraState extends State<_Finestra> {
  bool _spuntata = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AlertDialog(
      icon: Icon(Icons.gavel_rounded, color: tema.colorScheme.primary),
      title: const Text('Prima di attivare l\'AI'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final riga in testoPresaDAtto) ...[
              Text(riga, style: tema.textTheme.bodyMedium),
              const SizedBox(height: Gap.md),
            ],

            /*
             * 💡 **La casella dentro la finestra, non sotto i pulsanti.** Chi
             * scorre fino in fondo la trova dove ha finito di leggere: è
             * l'ultimo gesto della lettura, non un passaggio a parte.
             */
            CheckboxListTile(
              value: _spuntata,
              onChanged: (v) => setState(() => _spuntata = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'Ho letto e me ne rendo conto',
                style: tema.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          /*
           * ⛔ **Spento finché la casella non è spuntata**, e non «acceso che
           * poi avvisa»: un pulsante che si può toccare invita a toccarlo, e
           * chi lo tocca ha già smesso di leggere.
           */
          onPressed: _spuntata
              ? () => Navigator.of(context).pop(true)
              : null,
          child: const Text('Attiva l\'AI'),
        ),
      ],
    );
  }
}
