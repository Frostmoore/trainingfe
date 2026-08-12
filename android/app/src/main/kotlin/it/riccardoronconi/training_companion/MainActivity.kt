package it.riccardoronconi.training_companion

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * 🚨 `FlutterFragmentActivity`, NON `FlutterActivity` — A1.
 *
 * `local_auth` disegna la richiesta biometrica con `androidx.biometric.BiometricPrompt`,
 * che **pretende una `FragmentActivity`**: gli serve il `FragmentManager` per
 * attaccarci sopra il proprio dialogo.
 *
 * Con `FlutterActivity` il plugin lancia `PlatformException(no_fragment_activity)`
 * — e siccome `BloccoBiometrico.sblocca()` cattura tutto e risponde `false`, il
 * sintomo era: **l'interruttore c'è, si tocca, e non si accende**. Nessun errore,
 * nessun dialogo, niente.
 *
 * ⚠️ `disponibile()` invece rispondeva `true`, ed è per questo che la riga
 * compariva: `isDeviceSupported()` e `canCheckBiometrics` **non** passano dal
 * `BiometricPrompt`, quindi non si accorgevano di niente. Il difetto stava
 * esattamente nello scarto fra le due domande — «il telefono sa farlo?» e
 * «l'app può chiederlo?».
 *
 * 💡 Il cambio è sicuro per tutto il resto: `FlutterFragmentActivity` è la
 * stessa cosa con dentro il supporto ai fragment, ed è ciò che la
 * documentazione di `local_auth` chiede di usare.
 */
class MainActivity : FlutterFragmentActivity()
