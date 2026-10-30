# Build and deploy sabtawya web app
# Run from project root: .\build_web.ps1

$url = "https://fxclufgfkvfrhdleyndf.supabase.co"
$key = "sb_publishable_5j2lzDrUoKL3RUlJTIBoag_fU8ClIuT"

& "D:\dev\flutter\bin\flutter.bat" build web --release `
    "--dart-define=SUPABASE_URL=$url" `
    "--dart-define=SUPABASE_ANON_KEY=$key"

if ($LASTEXITCODE -eq 0) {
    npx vercel deploy --prod --project sabtawya build/web
}
