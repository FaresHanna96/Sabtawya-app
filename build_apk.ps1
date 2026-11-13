# Build the production Android APKs for the download page.
# Run from project root: .\build_apk.ps1   (then .\build_web.ps1 to publish)
#
# One APK per processor type instead of one universal APK: the universal file
# carried the engine three times (67 MB). Phones get:
#   sabtawya.apk        arm64-v8a, every phone from about 2017 on (~25 MB)
#   sabtawya-armv7.apk  armeabi-v7a, older 32-bit phones
# The emulator-only x86_64 build is not published.

$url = "https://fxclufgfkvfrhdleyndf.supabase.co"
$key = "sb_publishable_5j2lzDrUoKL3RUlJTIBoag_fU8ClIuT"
$flutter = "D:\dev\flutter\bin\flutter.bat"

& $flutter build apk --release --split-per-abi `
    "--dart-define=SUPABASE_URL=$url" `
    "--dart-define=SUPABASE_ANON_KEY=$key"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$out = "$PSScriptRoot\build\app\outputs\flutter-apk"
Copy-Item "$out\app-arm64-v8a-release.apk" "$PSScriptRoot\sabtawya.apk" -Force
Copy-Item "$out\app-armeabi-v7a-release.apk" "$PSScriptRoot\sabtawya-armv7.apk" -Force

foreach ($f in "sabtawya.apk", "sabtawya-armv7.apk") {
    $mb = [math]::Round((Get-Item "$PSScriptRoot\$f").Length / 1MB, 1)
    Write-Host "$f  $mb MB"
}
Write-Host "Update the size fact on web/apk.html if it changed, then run .\build_web.ps1"
