package com.smp.mytrainingcompanion

import android.os.Bundle
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
     * 🩺 Il percorso e il dislivello — 08/09/2026. Vedi [SaluteInPiu].
     */
    private val saluteInPiu by lazy { SaluteInPiu(this) }

    /**
     * 🚨 **Il ritorno della finestra di consenso si registra QUI, non dopo.**
     *
     * ⛔ `registerForActivityResult` chiamata piu' tardi lancia *«LifecycleOwners
     * must call register before they are STARTED»*: il registro dei risultati
     * dev'essere ricostruibile **dopo che il sistema ha ucciso il processo**
     * mentre la finestra era aperta.
     *
     * ⚠️ E qui non e' un caso di scuola: quella finestra e' un'altra app, e
     * mentre sta a schermo la nostra puo' essere buttata via per fare posto.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        saluteInPiu.registraIlRitorno()
    }

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

        /*
         * 🔗 Da dove viene questa installazione — 3b-V.3.3.
         *
         * ⚠️ **Un canale suo e non un metodo in più su quello dello schermo**:
         * sono due cose che non c'entrano niente l'una con l'altra, e un canale
         * che fa due mestieri è un canale che qualcuno un giorno spegne per il
         * mestiere sbagliato.
         *
         * 💡 Il perché di tutto il resto sta su [RiferimentoDellInstallazione].
         */
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RiferimentoDellInstallazione.CANALE,
        ).setMethodCallHandler { chiamata, risposta ->
            when (chiamata.method) {
                "leggi" -> RiferimentoDellInstallazione.leggi(applicationContext, risposta)

                else -> risposta.notImplemented()
            }
        }

        /*
         * 🩺 Il percorso di un allenamento e il dislivello — 08/09/2026.
         *
         * ⚠️ **Terzo canale, e non un metodo in piu' sugli altri due**: stessa
         * regola gia' scritta sopra — un canale che fa due mestieri e' un canale
         * che qualcuno un giorno spegne per il mestiere sbagliato.
         */
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SaluteInPiu.CANALE,
        ).setMethodCallHandler { chiamata, risposta ->
            saluteInPiu.gestisci(chiamata, risposta)
        }
    }

    companion object {
        /** 🚨 Deve combaciare con `SchermoProtetto._canale` lato Dart. */
        private const val CANALE = "mytrainingcompanion/schermo_protetto"
    }
}
