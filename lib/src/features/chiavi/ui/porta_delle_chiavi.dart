import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/providers_crypto.dart';
import '../../../core/crypto/servizio_chiavi.dart';
import '../../../core/theme/app_theme.dart';
import 'schermata_password_di_recupero.dart';
import 'schermata_ripristino.dart';

/// La porta davanti a tutto ciò che richiede la chiave maestra — S6.7.
///
/// 🚨 **L'ordine della sequenza vive qui, ed è la cosa facile da sbagliare.**
/// La domanda *«hai già usato questa app?»* deve arrivare **prima** che venga
/// generata una chiave maestra nuova. Sbagliando l'ordine ci si ritrova con due
/// chiavi — quella appena generata, con cui l'app comincia subito a lavorare, e
/// quella vera, ancora dietro il pacchetto sul server — e il primo salvataggio
/// scrive sopra al pacchetto buono, chiudendo la persona fuori dai propri
/// messaggi **per sempre**.
///
/// ⚠️ Il segnale che decide **non** è «l'utente è registrato»: lo è sempre, a
/// questo punto. È **«esiste il pacchetto incartato sul server»**, e lo
/// stabilisce [ServizioChiavi.stato].
///
/// ⏸️ **Oggi copre la sola chat**, che è l'unica cosa che ha bisogno della
/// chiave. Con S7 il canale porterà anche schede e piani alimentari, e a quel
/// punto questa porta va spostata più a monte — prima della schermata
/// principale, non davanti a una sezione.
class PortaDelleChiavi extends ConsumerWidget {
  const PortaDelleChiavi({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(statoChiaviProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => _Guasto(
            errore: e,
            riprova: () => ref.invalidate(statoChiaviProvider),
          ),
          data: (stato) => switch (stato) {
            StatoChiavi.pronto => child,
            StatoChiavi.daCreare => const SchermataPasswordDiRecupero(),
            StatoChiavi.daRipristinare => const SchermataRipristino(),
          },
        );
  }
}

/// ⚠️ Un guasto qui **non** porta alla creazione di una chiave nuova.
///
/// È la stessa prudenza di `ServizioChiavi.stato()`: sbagliando in questa
/// direzione si chiede di riprovare, sbagliando nell'altra si distrugge un
/// account.
class _Guasto extends StatelessWidget {
  const _Guasto({required this.errore, required this.riprova});

  final Object errore;
  final VoidCallback riprova;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: Gap.md),
              Text(
                'Non riesco a controllare le tue chiavi',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Gap.sm),
              Text(
                'Serve la rete per capire se questo account ha già una '
                'password di recupero. Riprova fra un momento.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Gap.lg),
              FilledButton(onPressed: riprova, child: const Text('Riprova')),
            ],
          ),
        ),
      ),
    );
  }
}
