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
/// account. ⛔ Non sparisce la palestra: si entra da **Profilo › Entra in una
/// palestra**, che esiste già e chiama `POST /account/join-gym`.
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
import '../branding_controller.dart';

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
                  Icon(
                    Icons.fitness_center_rounded,
                    size: 64,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(height: Gap.lg),

                  Text(
                    'Benvenuto',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
                   * 💡 **«Accedi» pieno e primo.** ⛔ Non è una gerarchia
                   * commerciale: è che questa schermata si rivede a ogni
                   * reinstallazione e a ogni cambio di telefono, e chi ha già un
                   * account è il caso più frequente di tutti. 🚨 È la stessa
                   * ragione per cui il 19/08 «continua senza palestra» era stato
                   * spostato sull'accesso invece che sulla registrazione.
                   */
                  FilledButton(
                    onPressed: _inCorso ? null : () => _vai(AppRoutes.login),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Accedi'),
                  ),
                  const SizedBox(height: Gap.md),

                  OutlinedButton(
                    onPressed: _inCorso ? null : () => _vai(AppRoutes.register),
                    style: OutlinedButton.styleFrom(
                      // 💡 Stessa altezza: sono due porte, non una porta e una
                      // nota a piè di pagina.
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Registrati'),
                  ),

                  const SizedBox(height: Gap.lg),

                  /*
                   * ⚠️ **Si dice che la palestra si aggiunge dopo.** ⛔ Chi ha in
                   * mano il codice della sua palestra e non lo vede da nessuna
                   * parte pensa di aver sbagliato app: una riga che glielo dice
                   * costa niente e gli evita di cercare.
                   */
                  Text(
                    'Se sei iscritto a una palestra potrai entrarci dopo, '
                    'dal tuo profilo, con il codice che ti ha dato.',
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
