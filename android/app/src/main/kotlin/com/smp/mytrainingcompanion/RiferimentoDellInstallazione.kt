package com.smp.mytrainingcompanion

import android.content.Context
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.plugin.common.MethodChannel

/**
 * Il «referrer» dell'installazione — 3b-V.3.3.
 *
 * ══ 🎯 A COSA SERVE ═══════════════════════════════════════════════════════
 *
 * Chi tocca un link d'invito **senza avere l'app** finisce sullo store. Dopo
 * l'installazione, l'app non ha nessun modo di sapere da quale invito veniva
 * quella persona: il link l'ha aperto il browser, non noi.
 *
 * 💡 Il Play Store porta con sé una stringa — il `referrer` — che era attaccata
 * all'URL dello store. Ci mettiamo dentro il token, e al primo avvio l'app se
 * lo ritrova.
 *
 *     …/store/apps/details?id=…&referrer=invito%3DAbC123…
 *                                        ↑ il nostro token
 *
 * ══ ⚠️ QUANDO NON FUNZIONA, E VA SAPUTO ═══════════════════════════════════
 *
 * ⛔ **Solo per le installazioni dal Play Store.** Un APK caricato a mano — cioè
 * come sta l'app oggi, in prova — non ha nessun referrer: la libreria risponde
 * `FEATURE_NOT_SUPPORTED` o una stringa vuota.
 *
 * 🚨 Quindi questo codice **oggi non fa niente**, ed è voluto: è la strada
 * giusta per quando l'app sarà pubblicata, e il ripiego (riaprire il link dopo
 * l'installazione) resta e continua a funzionare per tutti gli altri casi.
 *
 * ⚠️ **Non si scambia il silenzio per un guasto**: qui ogni risposta negativa
 * torna `null`, che vuol dire «nessun invito», non «errore». Un'eccezione
 * mostrata all'utente per una funzione che non sa nemmeno di avere sarebbe il
 * modo peggiore di aprire l'app.
 *
 * ══ 🚨 PERCHE' UN CANALE NOSTRO E NON UN PACCHETTO ════════════════════════
 *
 * La stessa ragione già scritta su [MainActivity] per `FLAG_SECURE`: sono
 * quaranta righe contro una dipendenza in più, e questo progetto ha già pagato
 * il prezzo dei plugin che non stanno dietro a Flutter.
 */
object RiferimentoDellInstallazione {

    /** 🚨 Deve combaciare con `RiferimentoDellInstallazione._canale` lato Dart. */
    const val CANALE = "mytrainingcompanion/riferimento_installazione"

    /**
     * Chiede al Play Store da dove viene questa installazione.
     *
     * ⚠️ **È asincrono e la connessione va chiusa**: il client tiene un legame
     * con il servizio del Play Store, e lasciarlo aperto è una perdita che non
     * si vede finché non se ne accumulano.
     *
     * 💡 `risposta` si chiama **una volta sola**: `onInstallReferrerSetupFinished`
     * e `onInstallReferrerServiceDisconnected` possono arrivare tutti e due, e
     * un `MethodChannel.Result` chiamato due volte fa esplodere Flutter con un
     * errore che non somiglia per niente alla sua causa.
     */
    fun leggi(context: Context, risposta: MethodChannel.Result) {
        val client = InstallReferrerClient.newBuilder(context).build()
        var giaRisposto = false

        fun rispondiUnaVoltaSola(valore: String?) {
            if (giaRisposto) return
            giaRisposto = true

            try {
                client.endConnection()
            } catch (_: Throwable) {
                // ⚠️ Chiudere una connessione già chiusa non è un problema di
                // nessuno: non deve impedire di rispondere.
            }

            risposta.success(valore)
        }

        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(codice: Int) {
                    if (codice != InstallReferrerClient.InstallReferrerResponse.OK) {
                        /*
                         * ⛔ `FEATURE_NOT_SUPPORTED` (APK caricato a mano),
                         * `SERVICE_UNAVAILABLE`, `DEVELOPER_ERROR`: sono tutti
                         * «nessun invito», non guasti da mostrare.
                         */
                        rispondiUnaVoltaSola(null)
                        return
                    }

                    val riferimento = try {
                        client.installReferrer.installReferrer
                    } catch (_: Throwable) {
                        null
                    }

                    rispondiUnaVoltaSola(riferimento)
                }

                override fun onInstallReferrerServiceDisconnected() {
                    rispondiUnaVoltaSola(null)
                }
            })
        } catch (_: Throwable) {
            // 🚨 `startConnection` può lanciare su alcuni dispositivi senza
            // Play Services. Anche quello è «nessun invito».
            rispondiUnaVoltaSola(null)
        }
    }
}
