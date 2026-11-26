# Tell every active user, with a push and an entry in the bell, that a new version is out.
# Tapping the push opens the app; a build below min_build then shows the full-screen update
# screen (the only way on is to install), and an older one gets the server's "please update".
#
#   .\send_update_push.ps1                  send for the version in pubspec.yaml
#   .\send_update_push.ps1 -DryRun          only say how many people it would reach
#   .\send_update_push.ps1 -ReminderOnly    point the Friday reminder at it, send nothing now
#
# build_web.ps1 runs this after every successful deploy (with -ReminderOnly for -NoPush).
# It always points the weekly Friday reminder (notify_update_reminder) at this version for
# four weeks. Sending twice for the same version is harmless: whoever already has that notice
# is skipped.
# Production only: the repo's supabase/ folder must be linked to the production project.
param([switch]$DryRun, [switch]$ReminderOnly)

$prodRef = "fxclufgfkvfrhdleyndf"
$linked = (Get-Content "$PSScriptRoot\supabase\.temp\project-ref" -ErrorAction SilentlyContinue)
if ($linked -ne $prodRef) {
    Write-Error "supabase/ is not linked to production ($prodRef). Not sending."
    exit 1
}

$verMatch = (Select-String -Path "$PSScriptRoot\pubspec.yaml" -Pattern '^version:\s*(\S+)\+(\d+)').Matches[0]
$ver = $verMatch.Groups[1].Value
$build = $verMatch.Groups[2].Value
$title = 'فيه تحديث جديد لسبتاوية ✨'
$body = "دوس هنا ونزّل النسخة $ver. لازم التحديث عشان التطبيق يفضل شغال."

$select = @"
select p.id, 'app_update', '$title', '$body'
from public.profiles p
where p.is_active and not p.is_hidden
  and not exists (select 1 from public.notifications n
                  where n.user_id = p.id and n.kind = 'app_update' and n.body = '$body')
"@

# Runs one statement on production and returns the CLI's output.
function Invoke-ProdSql([string]$sql) {
    # UTF-8 without a BOM, so the Arabic text reaches the database intact.
    $file = Join-Path $env:TEMP "sabtawya_update_push.sql"
    [System.IO.File]::WriteAllText($file, $sql, (New-Object System.Text.UTF8Encoding($false)))
    npx supabase db query --remote --yes -o json -f $file 2>&1 | Out-String
    Remove-Item $file -ErrorAction SilentlyContinue
}

# Remember the version and keep reminding every Friday until then (supabase/migrations/20261118006 and 008).
if (-not $DryRun) {
    # Four weeks on, rounded up to a Friday so the last Friday's reminder is not cut off.
    $end = (Get-Date).AddDays(28)
    while ($end.DayOfWeek -ne 'Friday') { $end = $end.AddDays(1) }
    $until = $end.ToString('yyyy-MM-dd')
    $cfg = "update public.app_config c set value = v.value from (values ('latest_app_version', '$ver'), ('latest_app_build', '$build'), ('update_reminder_until', '$until')) as v(key, value) where c.key = v.key returning c.key, c.value;"
    $saved = Invoke-ProdSql $cfg
    # All three rows must come back, or the reminder would name an old version.
    if (([regex]::Matches($saved, '"key"\s*:')).Count -ne 3) {
        Write-Host $saved
        Write-Error "The Friday reminder was NOT updated to $ver. Run .\send_update_push.ps1 again (add -ReminderOnly to send nothing now)."
        exit 1
    }
    Write-Host "Weekly Friday reminder now names $ver (build $build), on until $until."
}

if ($ReminderOnly) {
    Write-Host "No update notice sent."
    exit 0
}

if ($DryRun) {
    $sql = "select count(*) as would_send from ($select) x;"
} else {
    $sql = "insert into public.notifications (user_id, kind, title, body) $select returning user_id;"
}

$out = Invoke-ProdSql $sql
if ($DryRun) {
    $m = [regex]::Match($out, '"would_send":\s*"?(\d+)')
    Write-Host "Would notify $($m.Groups[1].Value) users about $ver."
} else {
    $n = ([regex]::Matches($out, '"user_id"')).Count
    Write-Host "Update notice for $ver sent to $n users (push goes out by itself)."
}
