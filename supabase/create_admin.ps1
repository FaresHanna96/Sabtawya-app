# create_admin.ps1
# Creates an admin account in Supabase.
# Run from the project root: .\supabase\create_admin.ps1 -ServiceRoleKey <key> -Password <new password>
#
# The service role key is in your Supabase dashboard:
#   Project Settings → API → service_role (secret)

param(
    [Parameter(Mandatory=$true)]
    [string]$ServiceRoleKey,

    # Passed in, never written here: this file is committed.
    [Parameter(Mandatory=$true)]
    [string]$Password
)

$env_json = Get-Content "$PSScriptRoot\..\env.json" | ConvertFrom-Json
$url      = $env_json.SUPABASE_URL

$email    = "admin@sabtawya.app"
$password = $Password
$fullName = "أمين خدمة"

$headers = @{
    "apikey"        = $ServiceRoleKey
    "Authorization" = "Bearer $ServiceRoleKey"
    "Content-Type"  = "application/json"
}

Write-Host "Step 1: Creating auth user..." -ForegroundColor Cyan

$body = @{
    email      = $email
    password   = $password
    user_metadata = @{ full_name = $fullName }
} | ConvertTo-Json

try {
    $result = Invoke-RestMethod `
        -Uri "$url/auth/v1/admin/users" `
        -Method POST `
        -Headers $headers `
        -Body $body `
        -ErrorAction Stop

    $userId = $result.id
    Write-Host "  Auth user created. ID: $userId" -ForegroundColor Green
} catch {
    $err = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($err.msg -like "*already*" -or $err.code -eq "email_exists") {
        Write-Host "  User already exists, continuing..." -ForegroundColor Yellow
        # Fetch existing user id
        $users = Invoke-RestMethod `
            -Uri "$url/auth/v1/admin/users?email=$email" `
            -Method GET `
            -Headers $headers
        $userId = $users.users[0].id
    } else {
        Write-Host "  Error: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Step 2: Promoting to admin via RPC..." -ForegroundColor Cyan

$rpcBody = @{ p_email = $email } | ConvertTo-Json

try {
    Invoke-RestMethod `
        -Uri "$url/rest/v1/rpc/promote_to_admin" `
        -Method POST `
        -Headers $headers `
        -Body $rpcBody `
        -ErrorAction Stop
    Write-Host "  Promoted to admin." -ForegroundColor Green
} catch {
    Write-Host "  RPC failed (function may be postgres-only). Trying direct upsert..." -ForegroundColor Yellow

    # Fallback: upsert into profiles directly with service_role
    $profileBody = @{
        id        = $userId
        full_name = $fullName
        email     = $email
        role      = "admin"
        is_active = $true
    } | ConvertTo-Json

    $profileHeaders = $headers.Clone()
    $profileHeaders["Prefer"] = "resolution=merge-duplicates"

    Invoke-RestMethod `
        -Uri "$url/rest/v1/profiles" `
        -Method POST `
        -Headers $profileHeaders `
        -Body $profileBody `
        -ErrorAction Stop
    Write-Host "  Profile upserted as admin." -ForegroundColor Green
}

Write-Host ""
Write-Host "Done! Admin account ready:" -ForegroundColor Green
Write-Host "  Email   : $email"
