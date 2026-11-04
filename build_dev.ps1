# Build the DEV/TEST version of the app (second Supabase project "sabtawya-dev").
#   .\build_dev.ps1            web build into build\web_dev
#   .\build_dev.ps1 -Deploy    web build + deploy to the sabtawya-dev Vercel site
#   .\build_dev.ps1 -Apk       also build the dev APK (installs next to the real app)
# Production is build_web.ps1 and is not touched by this script.
param([switch]$Deploy, [switch]$Apk)

$url = "https://atusdmohomycgqmhoovh.supabase.co"
$key = "sb_publishable_NxbpowUI1dV9Rl9e6hpLDA_mjBAgSlN"   # publishable (public) key of the dev project
$flutter = "D:\dev\flutter\bin\flutter.bat"

& $flutter build web --release --output "$PSScriptRoot\build\web_dev" "--dart-define=SUPABASE_URL=$url" "--dart-define=SUPABASE_ANON_KEY=$key"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($Deploy) {
    Copy-Item "$PSScriptRoot\vercel.json" "$PSScriptRoot\build\web_dev\vercel.json" -Force
    npx vercel deploy --prod --yes --project sabtawya-dev "$PSScriptRoot\build\web_dev"
}

if ($Apk) {
    $env:SABT_DEV = "1"
    & $flutter build apk --release "--dart-define=SUPABASE_URL=$url" "--dart-define=SUPABASE_ANON_KEY=$key"
    Remove-Item Env:\SABT_DEV
    $out = "$env:USERPROFILE\Downloads\sabtawya-dev.apk"
    Copy-Item "$PSScriptRoot\build\app\outputs\flutter-apk\app-release.apk" $out -Force
    Write-Host "Dev APK: $out"
}