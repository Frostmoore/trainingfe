allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
/*
 * ── #! compileSdk 36 imposto a TUTTI i moduli dei plugin - N21.4 ───────────
 *
 * `flutter_plugin_android_lifecycle`, che arriva con `file_picker`, pretende
 * «version 36 or later of the Android APIs». Alzarlo nel solo `:app` non basta:
 * a fallire e' `:file_picker:checkDebugAarMetadata`, cioe' il modulo del
 * plugin, che il suo compileSdk se lo porta dietro dal proprio build.gradle.
 *
 * /!\ E' un martello, e va saputo: tocca la compilazione di OGNI plugin, non
 * solo di quello che ha creato il problema. Si applica solo dove `android`
 * esiste davvero, e usa `maxOf` per non abbassare mai un modulo che stesse
 * gia' piu' in alto.
 *
 * * compileSdk dice contro quali API si compila, non come l'app si comporta:
 * quello lo decide `targetSdk`, che nessuno qui tocca.
 */
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { android ->
            val attuale = android.javaClass
                .getMethod("getCompileSdkVersion")
                .invoke(android) as? String

            val numero = attuale?.removePrefix("android-")?.toIntOrNull() ?: 0

            if (numero < 36) {
                android.javaClass
                    .getMethod("compileSdkVersion", Int::class.java)
                    .invoke(android, 36)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
