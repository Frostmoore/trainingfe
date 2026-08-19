package com.smp.mytrainingcompanion

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
class MainActivity : FlutterFragmentActivity() {

    /**
     * 🚨 `FLAG_SECURE` per le schermate usa e getta — N16.7.
     *
     * ── ⚠️ Perché un canale nostro invece di un pacchetto ─────────────────
     *
     * Perché sono venti righe contro una dipendenza in più, e questo progetto ha
     * già pagato il prezzo dei plugin che non stanno dietro a Flutter:
     * `file_picker` 11 non compila, la 8 usa API rimosse, e siamo fermi alla 10
     * con `compileSdk` forzato su tutti i sottoprogetti. Un `MethodChannel` di
     * venti righe non si rompe quando qualcun altro smette di aggiornare.
     *
     * ── 🚨 Cosa fa davvero, detto senza ottimismo ─────────────────────────
     *
     * `FLAG_SECURE` fa sì che il **sistema** rifiuti schermate e registrazione
     * dello schermo, e che la finestra non compaia nell'anteprima delle app
     * recenti. ⚠️ **Non impedisce di fotografare lo schermo con un altro
     * telefono**, e non c'è niente che possa impedirlo.
     *
     * 💡 È il motivo per cui l'interfaccia dice che l'usa e getta è una
     * cortesia, non una garanzia: promettere una sicurezza che non c'è è peggio
     * che non offrire la funzione, perché qualcuno manderebbe qualcosa che non
     * avrebbe mandato.
     *
     * ── ⚠️ E si spegne sempre ─────────────────────────────────────────────
     *
     * Il flag sta sulla **finestra**, non sulla schermata: acceso e dimenticato,
     * resterebbe attivo su tutta l'app. Il sintomo — «non riesco più a fare
     * schermate del diario» — non somiglierebbe mai alla sua causa.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANALE)
            .setMethodCallHandler { chiamata, risposta ->
                when (chiamata.method) {
                    "accendi" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        risposta.success(true)
                    }

                    "spegni" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        risposta.success(true)
                    }

                    else -> risposta.notImplemented()
                }
            }
    }

    companion object {
        /** 🚨 Deve combaciare con `SchermoProtetto._canale` lato Dart. */
        private const val CANALE = "mytrainingcompanion/schermo_protetto"
    }
}
