package com.smp.mytrainingcompanion

import android.content.Intent
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.contracts.ExerciseRouteRequestContract
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ElevationGainedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant

/**
 * 🩺 Le due cose di Health Connect che il pacchetto `health` non sa fare — 08/09/2026.
 *
 * ══ 📌 PERCHE' ESISTE ═════════════════════════════════════════════════════
 *
 * Il committente: *«se non metto la foto ci deve essere la forma del percorso
 * che ho fatto, e nella pagina di riassunto tutti i dati dell'allenamento,
 * quindi tempo velocità media inclinazione…»*.
 *
 * ⛔ Due dati su tre il pacchetto `health` non li dà, e per due ragioni diverse:
 *
 * | Dato | Perché non arriva |
 * |---|---|
 * | **Il percorso** | Torna sempre `ConsentRequired`: serve il consenso della persona, e il pacchetto non espone il modo di chiederlo |
 * | **Il dislivello** | `ElevationGainedRecord` **non è fra i tipi che il pacchetto conosce**. Non è un permesso mancante: il tipo proprio non c'è |
 *
 * 🚨 **Misurato l'08/09 sul telefono del committente**, non supposto: Health
 * Connect mostra **27 m** di dislivello per la camminata delle 10:49, scritti
 * da Zepp, e disegna la **forma del percorso** nella scheda. I dati ci sono
 * tutti e due; a mancare era la strada per prenderli.
 *
 * ══ ⚠️ PERCHE' UN CANALE NOSTRO E NON UN PACCHETTO IN PIU' ════════════════
 *
 * È la stessa ragione scritta su [MainActivity]: *«venti righe contro una
 * dipendenza in più, e questo progetto ha già pagato il prezzo dei plugin che
 * non stanno dietro a Flutter»*. 💡 E qui in più la libreria è **già in casa** —
 * `androidx.health.connect:connect-client` la tira dentro il pacchetto `health`:
 * qui la si dichiara solo per poterci compilare contro.
 */
class SaluteInPiu(private val activity: ComponentActivity) {

    /**
     * La richiesta in corso, se ce n'è una.
     *
     * 🚨 **Una sola alla volta, e il perché non è la pulizia**: la finestra di
     * consenso è un'activity di sistema, e due richieste in volo vorrebbero dire
     * due `MethodChannel.Result` per un ritorno solo. ⛔ Rispondere due volte
     * allo stesso `Result` fa terminare l'app con un `IllegalStateException` che
     * parla di tutt'altro.
     */
    private var inAttesa: MethodChannel.Result? = null

    private var richiestaPercorso: ActivityResultLauncher<String>? = null

    private var richiestaDislivello: ActivityResultLauncher<Set<String>>? = null

    private var inAttesaDiPermesso: MethodChannel.Result? = null

    private val ambito = CoroutineScope(Dispatchers.Main)

    /**
     * Va chiamata in `onCreate`, e **non più tardi**.
     *
     * ⛔ `registerForActivityResult` fuori da `onCreate` lancia
     * `LifecycleOwners must call register before they are STARTED`: il registro
     * dei risultati si costruisce mentre l'activity nasce, perché deve poter
     * essere ricostruito **dopo che il sistema ha ucciso il processo** mentre la
     * finestra di consenso era aperta.
     *
     * 💡 È esattamente il caso che qui succede davvero: la finestra di Health
     * Connect è un'altra app, e mentre è a schermo la nostra può essere buttata
     * via per fare posto.
     */
    fun registraIlRitorno() {
        richiestaPercorso = activity.registerForActivityResult(
            ExerciseRouteRequestContract(),
        ) { rotta ->
            val risposta = inAttesa
            inAttesa = null

            /*
             * ⚠️ **`null` non è un errore: è un «no».** La persona può chiudere la
             * finestra o rifiutare, e quello è un esito normale che l'app deve
             * saper raccontare — non un guasto da segnalare in rosso.
             */
            risposta?.success(
                rotta?.route?.map { punto ->
                    mapOf(
                        "lat" to punto.latitude,
                        "lon" to punto.longitude,
                        "quota" to punto.altitude?.inMeters,
                        "istante" to punto.time.toEpochMilli(),
                    )
                },
            )
        }

        /*
         * ⛰️ **Il permesso del dislivello, e si registra qui per la stessa
         * ragione**: il registro dei risultati dev'essere ricostruibile dopo che
         * il sistema ha ucciso il processo mentre la finestra era aperta.
         */
        richiestaDislivello = activity.registerForActivityResult(
            PermissionController.createRequestPermissionResultContract(),
        ) { concessi ->
            val risposta = inAttesaDiPermesso
            inAttesaDiPermesso = null

            risposta?.success(concessi.contains(PERMESSO_DISLIVELLO))
        }
    }

    fun gestisci(chiamata: MethodCall, risposta: MethodChannel.Result) {
        when (chiamata.method) {
            "percorso" -> chiediIlPercorso(chiamata, risposta)
            "dislivello" -> leggiIlDislivello(chiamata, risposta)
            "apriIPermessi" -> apriIPermessi(risposta)
            "chiediIlDislivello" -> chiediIlDislivello(risposta)
            else -> risposta.notImplemented()
        }
    }

    /**
     * Chiede il permesso di leggere il dislivello.
     *
     * ⛔ **Il pacchetto `health` non puo' chiederlo**, e non per una svista:
     * `ElevationGainedRecord` non e' fra i tipi che conosce, quindi non compare
     * nel foglio del consenso e resta `granted=false` per sempre.
     *
     * 🚨 Verificato l'08/09/2026 sul telefono: il dato in Health Connect c'era
     * — 27 m sulla camminata delle 10:49 — il permesso no, e la card non
     * mostrava niente. ⚠️ **Un dato assente per un permesso mai chiesto somiglia
     * a un dato che non esiste**, ed e' il difetto piu' insidioso di tutta questa
     * storia: e' successo tre volte in due giorni.
     *
     * 💡 A differenza dei percorsi, questo permesso **si puo' chiedere**:
     * compare la solita finestra di sistema.
     */
    private fun chiediIlDislivello(risposta: MethodChannel.Result) {
        val lanciatore = richiestaDislivello

        if (lanciatore == null || inAttesaDiPermesso != null) {
            risposta.success(false)
            return
        }

        ambito.launch {
            try {
                if (HealthConnectClient.getSdkStatus(activity) !=
                    HealthConnectClient.SDK_AVAILABLE
                ) {
                    risposta.success(false)
                    return@launch
                }

                /*
                 * ⛔ **Prima si guarda se c'e' gia', e non e' un'ottimizzazione.**
                 * 🚨 Chi ha concesso i permessi mesi fa non ripassa mai dalla
                 * schermata del consenso: se questa aprisse una finestra a ogni
                 * avvio sarebbe insopportabile, e se non la aprisse mai il
                 * dislivello non arriverebbe a nessuno di loro.
                 *
                 * 💡 Con il controllo, chiamarla e' innocuo: risponde e basta.
                 */
                val gia = withContext(Dispatchers.IO) {
                    HealthConnectClient.getOrCreate(activity)
                        .permissionController
                        .getGrantedPermissions()
                }

                if (gia.contains(PERMESSO_DISLIVELLO)) {
                    risposta.success(true)
                    return@launch
                }

                inAttesaDiPermesso = risposta

                lanciatore.launch(setOf(PERMESSO_DISLIVELLO))
            } catch (errore: Throwable) {
                inAttesaDiPermesso = null
                risposta.success(false)
            }
        }
    }

    /**
     * Chiede alla persona il percorso di **una** sessione.
     *
     * ══ 🚨 PERCHE' UNA ALLA VOLTA E NON TUTTE ═════════════════════════════
     *
     * ⛔ Esiste anche un permesso «tutti i percorsi», `READ_EXERCISE_ROUTES`, che
     * si concede da un interruttore dentro Health Connect. 🚨 **Su questo
     * telefono quell'interruttore non compare**, verificato l'08/09 con un dump
     * della schermata: la sezione «Accesso aggiuntivo» è vuota.
     *
     * 💡 Questa strada invece funziona: `RouteRequestActivity` esiste ed è
     * esportata. ⚠️ Si rifiuta di aprirsi per chi non ha `READ_EXERCISE` — provato
     * da `adb`, che si è preso un `SecurityException` — e noi quel permesso ce
     * l'abbiamo.
     *
     * ⛔ **Va lanciata con l'app in primo piano.** Google: *«when your app runs in
     * the background and tries to read an exercise route created by another app,
     * Health Connect returns ConsentRequired, even if your app has Always
     * allow»*.
     */
    private fun chiediIlPercorso(chiamata: MethodCall, risposta: MethodChannel.Result) {
        val idSessione = chiamata.argument<String>("id")

        if (idSessione.isNullOrBlank()) {
            risposta.error("id_mancante", "Serve l'id della sessione.", null)
            return
        }

        val lanciatore = richiestaPercorso

        if (lanciatore == null) {
            risposta.error(
                "non_registrato",
                "registraIlRitorno() non è stata chiamata in onCreate.",
                null,
            )
            return
        }

        if (inAttesa != null) {
            risposta.error(
                "gia_in_corso",
                "C'è già una richiesta di percorso aperta.",
                null,
            )
            return
        }

        inAttesa = risposta

        try {
            lanciatore.launch(idSessione)
        } catch (errore: Throwable) {
            inAttesa = null
            risposta.error("non_lanciabile", errore.message, null)
        }
    }

    /**
     * Il dislivello salito, metro per metro, in una finestra di tempo.
     *
     * ⚠️ **Sono tanti record brevi, non un totale**: Health Connect scrive un
     * `ElevationGainedRecord` per intervallo. 💡 Chi chiama somma quelli che
     * cadono dentro l'allenamento — e qui si torna la lista grezza apposta,
     * perché la decisione di cosa sta «dentro» è una regola di prodotto e vive
     * in Dart, dove è già scritta per le altre metriche.
     */
    private fun leggiIlDislivello(chiamata: MethodCall, risposta: MethodChannel.Result) {
        val da = chiamata.argument<Long>("da")
        val a = chiamata.argument<Long>("a")

        if (da == null || a == null) {
            risposta.error("finestra_mancante", "Servono «da» e «a» in millisecondi.", null)
            return
        }

        ambito.launch {
            try {
                /*
                 * ⛔ **`getSdkStatus` prima di `getOrCreate`.** Su un telefono
                 * senza Health Connect `getOrCreate` lancia, e l'eccezione
                 * parlerebbe di un provider mancante a chi ha solo aperto la
                 * pagina di un allenamento.
                 */
                if (HealthConnectClient.getSdkStatus(activity) !=
                    HealthConnectClient.SDK_AVAILABLE
                ) {
                    risposta.success(null)
                    return@launch
                }

                val righe = withContext(Dispatchers.IO) {
                    HealthConnectClient.getOrCreate(activity).readRecords(
                        ReadRecordsRequest(
                            recordType = ElevationGainedRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(
                                Instant.ofEpochMilli(da),
                                Instant.ofEpochMilli(a),
                            ),
                        ),
                    ).records
                }

                risposta.success(
                    righe.map { riga ->
                        mapOf(
                            "inizio" to riga.startTime.toEpochMilli(),
                            "fine" to riga.endTime.toEpochMilli(),
                            "metri" to riga.elevation.inMeters,
                        )
                    },
                )
            } catch (errore: Throwable) {
                /*
                 * ⚠️ **`null` e non un errore**: senza il permesso
                 * `READ_ELEVATION_GAINED` questa chiamata lancia, ed è uno stato
                 * normale — non tutti lo concedono. ⛔ Un errore qui farebbe
                 * comparire un riquadro rosso su una pagina che per il resto
                 * funziona.
                 */
                risposta.success(null)
            }
        }
    }

    /**
     * Apre la schermata di Health Connect con i permessi della nostra app.
     *
     * ⛔ **Serve perche' un permesso non si puo' chiedere da codice.** Google, su
     * `READ_EXERCISE_ROUTES`: *«attempts to request the permission by
     * applications will be ignored»*. 🚨 L'unica cosa che possiamo fare e'
     * portarci la persona.
     *
     * ⚠️ **E potrebbe non trovarci niente**: su Android 16 quella schermata, per
     * la nostra app, non mostra la voce «Percorsi di allenamento» — verificato
     * l'08/09/2026 con un dump della UI. 💡 Per questo il pulsante che la apre
     * non e' l'unica strada, e accanto resta la richiesta per singola uscita.
     */
    private fun apriIPermessi(risposta: MethodChannel.Result) {
        try {
            activity.startActivity(
                Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS")
                    .putExtra(Intent.EXTRA_PACKAGE_NAME, activity.packageName),
            )

            risposta.success(true)
        } catch (errore: Throwable) {
            /*
             * ⚠️ Su un telefono senza Health Connect quell'azione non la gestisce
             * nessuno. ⛔ `false` e non un errore: chi chiama deve poter dire
             * «non si apre» senza far comparire un riquadro rosso.
             */
            risposta.success(false)
        }
    }

    companion object {
        /** 🚨 Deve combaciare con `SaluteInPiu._canale` lato Dart. */
        const val CANALE = "mytrainingcompanion/salute_in_piu"

        /**
         * ⚠️ **Si ricava dalla classe, non si scrive a mano.**
         *
         * ⛔ La stringa sarebbe `android.permission.health.READ_ELEVATION_GAINED`,
         * e scriverla a mano vorrebbe dire che un refuso non fallisce: chiede un
         * permesso che non esiste, il sistema non concede niente, e il sintomo e'
         * un dato che manca.
         */
        private val PERMESSO_DISLIVELLO =
            HealthPermission.getReadPermission(ElevationGainedRecord::class)
    }
}
