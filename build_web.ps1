# Build and deploy sabtawya web app
# Run from project root: .\build_web.ps1

$url = "https://fxclufgfkvfrhdleyndf.supabase.co"
$key = "sb_publishable_5j2lzDrUoKL3RUlJTIBoag_fU8ClIuT"

& "D:\dev\flutter\bin\flutter.bat" build web --release `
    "--dart-define=SUPABASE_URL=$url" `
    "--dart-define=SUPABASE_ANON_KEY=$key"

if ($LASTEXITCODE -eq 0) {
    # The download page (apk.html) serves the APK from the site itself, so it
    # ships with every deploy. Without it the deploy would drop the APK and the
    # download button would 404, so stop instead.
    if (-not (Test-Path "$PSScriptRoot\sabtawya.apk")) {
        Write-Error "sabtawya.apk is missing from the project root: build it first (flutter build apk) and copy it there."
        exit 1
    }
    Copy-Item "$PSScriptRoot\sabtawya.apk" build/web/sabtawya.apk -Force

    # Copy cache-control config so Vercel serves assets with proper headers
    Copy-Item vercel.json build/web/vercel.json -Force
    npx vercel deploy --prod --project sabtawya build/web
    # Free plan: 10 GB of deployment storage. Keep only the live deployment
    # and one backup (only after a successful deploy).
    if ($LASTEXITCODE -eq 0) { & "$PSScriptRoot\prune_vercel.ps1" -Project sabtawya }
}
