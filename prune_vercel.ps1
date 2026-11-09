# Delete old Vercel deployments of one project, keeping the newest ones.
#   .\prune_vercel.ps1 -Project sabtawya            keep the newest 2
#   .\prune_vercel.ps1 -Project sabtawya-dev -Keep 3
#   .\prune_vercel.ps1 -Project sabtawya -DryRun    only list what would go
#
# Every deploy stores a full copy of the site (about 45 MB), and the free plan
# allows 10 GB of deployment storage. build_web.ps1 and build_dev.ps1 call this
# after a successful deploy, so storage stays flat: the live deployment plus a
# backup to roll back to.
param(
    [Parameter(Mandatory = $true)][string]$Project,
    [int]$Keep = 2,
    [switch]$DryRun
)

# Never go below 2: the newest is the live site, the one before it is the
# rollback.
if ($Keep -lt 2) { $Keep = 2 }

function Get-Deployments($name) {
    $all = @()
    $next = $null
    do {
        $cli = @('ls', $name, '--yes', '--format', 'json')
        if ($next) { $cli += @('--next', "$next") }
        $out = & npx vercel @cli 2>$null | Out-String
        $at = $out.IndexOf('{')
        if ($at -lt 0) { return $null }          # CLI failed: touch nothing
        $json = $out.Substring($at) | ConvertFrom-Json
        $all += $json.deployments
        $next = $json.pagination.next
    } while ($next -and $json.deployments.Count -gt 0)
    return $all
}

$deployments = Get-Deployments $Project
if ($null -eq $deployments -or $deployments.Count -eq 0) {
    Write-Host "prune: could not list deployments of '$Project', nothing deleted."
    exit 0
}

$sorted = $deployments | Sort-Object createdAt -Descending
$old = @($sorted | Select-Object -Skip $Keep)
Write-Host ("prune: {0} has {1} deployments, keeping the newest {2}, removing {3}" -f $Project, $sorted.Count, $Keep, $old.Count)
if ($old.Count -eq 0) { exit 0 }

# @() keeps it a list: with a single old deployment PowerShell would otherwise
# hand back one string, and $urls[0..0] would be its first letter.
$urls = @($old | ForEach-Object { 'https://' + $_.url })
if ($DryRun) {
    $urls | ForEach-Object { Write-Host "  would remove $_" }
    exit 0
}

for ($i = 0; $i -lt $urls.Count; $i += 20) {
    $batch = $urls[$i..([Math]::Min($i + 19, $urls.Count - 1))]
    & npx vercel rm @batch --yes 2>&1 | Select-String -Pattern 'Removed|Error' | Select-Object -Last 1
}
