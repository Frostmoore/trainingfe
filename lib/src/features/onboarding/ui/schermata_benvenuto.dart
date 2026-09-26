/// La prima schermata: entra, o iscriviti — 3b-J.1, 27/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// 📌 *«al primo accesso, rimuovi l'opzione di registrarsi con una palestra,
/// non serve. Metti solo Login o Registrati. Poi per accedere con una palestra
/// si farà dopo che l'utente si è già registrato»*.
///
/// ══ ⛔ COSA SPARISCE, E COSA NO ═══════════════════════════════════════════
///
/// Sparisce `GymCodeScreen`: il campo del codice palestra **prima** di avere un
/// account.
///
/// 🆕 ⛔ **E dal 15/09/2026 non c'è più nemmeno dopo.** Si entra in una palestra
/// **solo da un link d'invito**: `POST /account/join-gym` non esiste più, e la
/// voce «Entra in una palestra» nel profilo è stata tolta. 💡 Un codice che si
/// digita è un codice che si può indovinare o passare a voce; un invito ha un
/// destinatario, una scadenza e un solo uso.
///
/// 💡 **È anche l'ordine giusto.** Il codice chiesto per primo faceva credere di
/// doverne avere uno: chi non ce l'ha si fermava a leggere due volte prima di
/// capire che poteva proseguire. E chi ce l'ha lo digita comunque, solo più
/// tardi e sapendo già cosa sta facendo.
///
/// ══ 🚨 IL PREZZO, E COME È STATO PAGATO ═══════════════════════════════════
///
/// Prima, il codice digitato qui vestiva l'app dei colori della palestra **fin
/// dalla prima schermata**. ⛔ Toglierlo, da solo, avrebbe lasciato neutro un
/// iscritto che reinstalla l'app — con il server che sa benissimo in che
/// palestra sta.
///
/// 💡 Per questo il branding adesso **segue l'account**: `/auth/login` e
/// `/auth/me` lo restituivano già, e nessuno lo leggeva. È anche più giusto —
/// la palestra è un fatto dell'utente, non di un codice in cache.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/ui/widgets/social_buttons.dart';
import '../branding_controller.dart';
import 'widgets/marchio_in_cima.dart';

class SchermataBenvenuto extends ConsumerStatefulWidget {
  const SchermataBenvenuto({super.key});

  @override
  ConsumerState<SchermataBenvenuto> createState() => _SchermataBenvenutoState();
}

class _SchermataBenvenutoState extends ConsumerState<SchermataBenvenuto> {
  bool _inCorso = false;

  /// Registra la scelta e va avanti.
  ///
  /// ══ ⚠️ `senzaPalestra()` SERVE ANCHE QUI ══════════════════════════════
  ///
  /// 🚨 Non vuol dire «non avrò mai una palestra»: vuol dire **«la scelta è
  /// fatta»**, ed è la condizione che il router guarda (`sceltaFatta`). ⛔ Senza,
  /// la regola 5 di `destinazione()` rimanda qui a ogni passo, e i due pulsanti
  /// non porterebbero da nessuna parte.
  ///
  /// 💡 Chi poi entra in una palestra la sovrascrive con `adotta()`, che rimette
  /// `senzaPalestra` a `false`.
  Future<void> _vai(String dove) async {
    setState(() => _inCorso = true);

    await ref.read(brandingControllerProvider.notifier).senzaPalestra();

    if (mounted) {
      setState(() => _inCorso = false);

      context.go(dove);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final branding = ref.watch(brandingControllerProvider).branding;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Gap.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  /*
                   * ══ 🆕 LO STESSO MARCHIO DELLE ALTRE DUE — 14/09/2026 ════
                   *
                   * ⛔ **Qui c'era un manubrio nudo, e a due tocchi di
                   * distanza — `/accedi`, `/registrati` — ce n'era un altro:
                   * un cerchio verde con una «T».** Tre schermate consecutive,
                   * due marchi diversi.
                   *
                   * 🚨 **E il nome dell'applicazione non compariva**, proprio
                   * nell'unica schermata che si vede **prima** di avere un
                   * account: chi la apre è esattamente chi può ancora
                   * chiedersi cosa ha installato.
                   *
                   * 💡 `MarchioInCima` lo disegna una volta sola per tutte e
                   * tre, e sceglie da sé fra la palestra e l'applicazione.
                   */
                  MarchioInCima(branding: branding),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Tieni traccia dei tuoi allenamenti e di quello che mangi.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Gap.xl),

                  /*
                   * ══ 🆕 «REGISTRATI» PIENO E PRIMO — 14/09/2026 ═══════════
                   *
                   * 📌 Il committente, dopo il giro sull'emulatore: *«mi pare
                   * evidente che se ci si arriva solo se non si ha un account,
                   * la scelta principale deve essere Registrati»*.
                   *
                   * ⛔ **Qui c'era scritto il contrario**, e l'argomento non era
                   * sbagliato: questa schermata si rivede a ogni
                   * reinstallazione e a ogni cambio di telefono, e in quei casi
                   * un account c'è già. 🚨 Ci si arriva ogni volta che **non
                   * c'è una sessione sul telefono**, che non è la stessa cosa
                   * di «non c'è un account».
                   *
                   * 💡 **Ma i due errori non costano uguale**, ed è questo che
                   * decide:
                   *
                   * | Chi sbaglia porta | Cosa trova |
                   * |---|---|
                   * | Chi rientra e tocca «Registrati» | un modulo, e capisce subito |
                   * | ⛔ Chi è nuovo e tocca «Accedi» | un rifiuto, e **non sa perché** |
                   *
                   * ⚠️ E per un'app che non è ancora pubblicata, le prime
                   * installazioni sono quasi tutte prime volte.
                   */
                  FilledButton(
                    onPressed: _inCorso ? null : () => _vai(AppRoutes.register),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Registrati'),
                  ),
                  const SizedBox(height: Gap.md),

                  OutlinedButton(
                    onPressed: _inCorso ? null : () => _vai(AppRoutes.login),
                    style: OutlinedButton.styleFrom(
                      // 💡 Stessa altezza: sono due porte, non una porta e una
                      // nota a piè di pagina.
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Accedi'),
                  ),

                  /*
                   * 🆕 🔑 **«Continua con Google» sta QUI** — voce 25, 26/09/2026.
                   *
                   * 📌 Il committente: *«i tasti accedi con google e accedi con
                   * appleid devono stare prima di cliccare su accedi»*.
                   *
                   * 🔑 Ed è la posizione giusta anche per una ragione che non è
                   * di gusto: entrare con Google **non è né registrarsi né
                   * accedere** — è una terza porta che fa la cosa giusta da sola
                   * (collega l'account se esiste, lo crea se non esiste).
                   * ⛔ Nasconderla dentro «Accedi» la mostrerebbe solo a chi ha
                   * già scelto di essere uno che rientra.
                   *
                   * ⚠️ **Niente caselle dei consensi qui**: su questa schermata
                   * nessuno sa ancora se la persona si iscrive o rientra. Se il
                   * server dice che è un primo accesso, `SocialButtons` apre le
                   * due dichiarazioni e riprova (vedi `le_dichiarazioni.dart`).
                   *
                   * 💡 Se il server non dichiara nessun fornitore, qui non
                   * compare niente — nemmeno il «oppure».
                   */
                  const SocialButtons(),

                  const SizedBox(height: Gap.lg),

                  /*
                   * ⚠️ **Si dice che la palestra si aggiunge dopo.** ⛔ Chi ha in
                   * mano il codice della sua palestra e non lo vede da nessuna
                   * parte pensa di aver sbagliato app: una riga che glielo dice
                   * costa niente e gli evita di cercare.
                   */
                  /*
                   * 🆕 ⛔ **Qui c'era «col codice che ti ha dato»** — 17/09/2026.
                   *
                   * 🚨 Il codice digitato è stato tolto il 15/09: in palestra si
                   * entra **solo da un invito**. ⚠️ La frase mandava chi si era
                   * appena registrato a cercare nel profilo una voce che non
                   * esiste più, con in mano un codice che non serve a niente.
                   */
                  Text(
                    'Se sei iscritto a una palestra, chiedile il link '
                    "d'invito: aprendolo entri con un tocco.",
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
