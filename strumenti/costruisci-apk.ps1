# Costruisce l'APK con i `--dart-define` giusti, e lo verifica.
#
# ══ 🚨 PERCHÉ QUESTO SCRIPT ESISTE ═══════════════════════════════════════════
#
# `fvm flutter build apk --release` **compila benissimo** e produce un APK che
# punta a `http://10.0.2.2:8123`, cioè all'emulatore. Su un telefono vero quel
# numero non esiste: le richieste non falliscono, **restano appese** fino ai 15
# secondi di `connectTimeout`.
#
# ⚠️ Il sintomo non assomiglia alla causa. L'app resta sulla schermata «App
# bloccata» dopo che l'impronta è stata accettata — perché finché `/auth/me` non
# risponde lo stato è `unknown`, e la regola 1 del router dice «resta dove sei».
# Nessun errore, nessun crash, niente nel logcat. È successo il 20/08/2026.
#
# 🚨 Ed era già scritto in grassetto in tre handoff: *«--dart-define=ENV=staging
# non è facoltativo»*. Una regola che sta solo in un documento viene saltata: se
# si può sbagliare da riga di comando, prima o poi si sbaglia. Questo script
# esiste perché il comando giusto sia **più corto** di quello sbagliato.
#
# Uso:
#   .\strumenti\costruisci-apk.ps1                    # staging, costruisce
#   .\strumenti\costruisci-apk.ps1 -Installa          # ...e lo mette sul telefono
#   .\strumenti\costruisci-apk.ps1 -Ambiente production

param(
    [ValidateSet('staging', 'production')]
    [string]$Ambiente = 'staging',

    [switch]$Installa,

    # Dove copiarlo per mandarlo a qualcuno. Vuoto = non copiare.
    [string]$CopiaIn = ''
)

$ErrorActionPreference = 'Stop'
$radice = Split-Path -Parent $PSScriptRoot
Push-Location $radice

try {
    # ══ 🆕 LA VERSIONE, PRIMA DI COMPILARE — FASE 10.1 ═══════════════════
    #
    # 🚨 Fino al 21/08 `pubspec.yaml` diceva `1.0.0+1` e non l'aveva mai
    # toccata nessuno: ogni APK si dichiarava «1.0.0» con `versionCode` 1.
    #
    # ⚠️ Due guai: il cancello della versione confronta numeri tutti uguali, e
    # **il Play Store rifiuta un caricamento con un `versionCode` già usato** —
    # alla prima pubblicazione passa, alla seconda no.
    #
    # 💡 Si controlla qui e non in un documento: una regola che si può violare
    # da riga di comando, prima o poi si viola. È la stessa lezione dell'ENV.
    $riga = (Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()

    if ($riga -eq '1.0.0+1') {
        throw "pubspec.yaml e' ancora a 1.0.0+1: la versione non e' mai stata alzata (FASE 10.1)."
    }

    if ($riga -notmatch '^(\d+)\.(\d+)\.(\d+)\+(\d+)$') {
        throw "versione '$riga' non riconosciuta: serve X.Y.Z+N."
    }

    $atteso = [int]$Matches[1] * 10000 + [int]$Matches[2] * 100 + [int]$Matches[3]

    if ([int]$Matches[4] -ne $atteso) {
        throw "versionCode $($Matches[4]) non torna: per $($Matches[1]).$($Matches[2]).$($Matches[3]) deve essere $atteso (major*10000 + minor*100 + patch)."
    }

    Write-Host "Versione: $riga (versionCode $atteso)" -ForegroundColor Green

    Write-Host "Costruisco per '$Ambiente'..." -ForegroundColor Cyan
    fvm flutter build apk --release --dart-define=ENV=$Ambiente
    if ($LASTEXITCODE -ne 0) { throw "la compilazione è fallita" }

    $apk = Join-Path $radice 'build\app\outputs\flutter-apk\app-release.apk'

    # ══ 🚨 La verifica, e non è cerimonia ═══════════════════════════════════
    #
    # `--dart-define` è una costante di compilazione: se è arrivata, lo `switch`
    # su `AppEnvironment` viene ripiegato e l'URL dell'emulatore **sparisce dal
    # binario**. Se è ancora lì, il define non è passato — e senza questo
    # controllo si scoprirebbe solo col telefono in mano.
    # 💡 Oggi staging e produzione hanno lo stesso host: il controllo che conta
    # è che l'URL dell'emulatore **non ci sia**. Il giorno in cui i due host si
    # separeranno, qui va messo l'host per ambiente — e il `switch` è il posto.
    $atteso = switch ($Ambiente) {
        'staging'    { 'training.riccardoronconi.it' }
        'production' { 'training.riccardoronconi.it' }
    }

    $py = @"
import sys, zipfile
z = zipfile.ZipFile(r'$apk')
so = [n for n in z.namelist() if n.endswith('libapp.so')]
if not so:
    sys.exit('libapp.so non trovato nell APK')
d = z.read(so[0])
locale = d.count(b'10.0.2.2:8123')
giusto = d.count(b'$atteso')
print(f'url locale: {locale} - url {"$Ambiente"}: {giusto}')
if locale or not giusto:
    sys.exit('APK COSTRUITO MALE: manca --dart-define=ENV')
"@

    $py | python -
    if ($LASTEXITCODE -ne 0) { throw "l'APK punta all'ambiente sbagliato" }

    Write-Host "OK: l'APK punta a $Ambiente" -ForegroundColor Green

    if ($CopiaIn) {
        Copy-Item $apk $CopiaIn -Force
        Write-Host "Copiato in $CopiaIn"
    }

    if ($Installa) {
        # ⚠️ `install -r` e non `flutter install`: il secondo disinstalla prima,
        # e disinstallare porta via l'archivio locale — che è l'unico posto dove
        # vivono sonno, battito e allenamenti.
        adb install -r $apk
        if ($LASTEXITCODE -ne 0) { throw "l'installazione è fallita" }
    }
}
finally {
    Pop-Location
}
