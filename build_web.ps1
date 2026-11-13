# Build and deploy sabtawya web app
# Run from project root: .\build_web.ps1

$url = "https://fxclufgfkvfrhdleyndf.supabase.co"
$key = "sb_publishable_5j2lzDrUoKL3RUlJTIBoag_fU8ClIuT"

& "D:\dev\flutter\bin\flutter.bat" build web --release `
    "--dart-define=SUPABASE_URL=$url" `
    "--dart-define=SUPABASE_ANON_KEY=$key"

if ($LASTEXITCODE -eq 0) {
    # The download page (apk.html) serves the APKs from the site itself, so
    # they ship with every deploy. Two APKs (see build_apk.ps1): the main arm64
    # one and one for old 32-bit phones. Both must be there, or a download
    # link would 404, so stop instead.
    foreach ($apk in "sabtawya.apk", "sabtawya-armv7.apk") {
        if (-not (Test-Path "$PSScriptRoot\$apk")) {
            Write-Error "$apk is missing from the project root: run build_apk.ps1 first."
            exit 1
        }
        Copy-Item "$PSScriptRoot\$apk" "build/web/$apk" -Force
    }

    # Copy cache-control config so Vercel serves assets with proper headers
    Copy-Item vercel.json build/web/vercel.json -Force
    npx vercel deploy --prod --project sabtawya build/web
    # Free plan: 10 GB of deployment storage. Keep only the live deployment
    # and one backup (only after a successful deploy).
    if ($LASTEXITCODE -eq 0) { & "$PSScriptRoot\prune_vercel.ps1" -Project sabtawya }
}
