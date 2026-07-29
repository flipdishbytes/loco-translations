# Delete Loco assets whose IDs were removed from the source catalog by a push.
#
# Environment variables:
#   locoWriteKey      - Loco API full-access key
#   sourceFile        - Absolute path to the current source JSON catalog
#   sourceFileRelative - Repository-relative path to the source JSON catalog
#   workspace         - Checked-out repository root
#   previousRevision  - Commit SHA before the triggering push
#   deleteMaxCount    - Maximum assets allowed in one run; defaults to 20

$ErrorActionPreference = 'Stop'

$locoWriteKey = $env:locoWriteKey
$sourceFile = $env:sourceFile
$sourceFileRelative = $env:sourceFileRelative
$workspace = $env:workspace
$previousRevision = $env:previousRevision
$deleteMaxCount = 0

if (
    -not [int]::TryParse($env:deleteMaxCount, [ref]$deleteMaxCount) -or
    $deleteMaxCount -lt 1
) {
    $deleteMaxCount = 20
}

if ([string]::IsNullOrWhiteSpace($locoWriteKey)) {
    throw 'locoWriteKey is not set.'
}
if ([string]::IsNullOrWhiteSpace($sourceFile)) {
    throw 'sourceFile is not set.'
}
if ([string]::IsNullOrWhiteSpace($sourceFileRelative)) {
    throw 'sourceFileRelative is not set.'
}
if ([string]::IsNullOrWhiteSpace($workspace)) {
    throw 'workspace is not set.'
}
if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
    throw "Source translation file not found: $sourceFile"
}

if ([string]::IsNullOrWhiteSpace($previousRevision)) {
    Write-Host 'No previous push revision is available; skipping automatic Loco deletion.'
    return
}
if ($previousRevision -match '^0+$') {
    Write-Host 'The push has no previous revision; skipping automatic Loco deletion.'
    return
}
if ($previousRevision -notmatch '^[0-9a-fA-F]{40}$') {
    throw "previousRevision must be a 40-character commit SHA, got: $previousRevision"
}

$commitReference = "$previousRevision^{commit}"
& git -C $workspace cat-file -e $commitReference 2>$null
if ($LASTEXITCODE -ne 0) {
    & git -C $workspace fetch --no-tags --depth=1 origin $previousRevision
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to fetch previous revision: $previousRevision"
    }
}

$catalogReference = "${previousRevision}:$sourceFileRelative"
& git -C $workspace cat-file -e $catalogReference 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "No source catalog existed at $previousRevision; nothing can be deleted."
    return
}

$previousRawLines = @(& git -C $workspace show $catalogReference)
if ($LASTEXITCODE -ne 0) {
    throw "Failed to read $sourceFileRelative from revision $previousRevision."
}
$previousRaw = $previousRawLines -join [System.Environment]::NewLine
$currentRaw = Get-Content -LiteralPath $sourceFile -Raw -Encoding utf8

$previousData = $previousRaw | ConvertFrom-Json -AsHashtable
$currentData = $currentRaw | ConvertFrom-Json -AsHashtable
$currentKeys = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal
)
foreach ($key in $currentData.Keys) {
    $currentKeys.Add($key) | Out-Null
}

$removedKeys = [System.Collections.Generic.List[string]]::new()
foreach ($key in $previousData.Keys) {
    if (-not $currentKeys.Contains($key)) {
        $removedKeys.Add($key)
    }
}

if ($removedKeys.Count -eq 0) {
    Write-Host 'No translation keys were removed from the source catalog.'
    return
}
if ($removedKeys.Count -gt $deleteMaxCount) {
    throw "Refusing to delete $($removedKeys.Count) Loco assets; deleteMaxCount is $deleteMaxCount."
}

Write-Host "Deleting $($removedKeys.Count) Loco asset(s) removed from ${sourceFileRelative}:"
foreach ($key in $removedKeys) {
    Write-Host "  - $key"
}

$headers = @{
    'Authorization' = "Loco $locoWriteKey"
    'Accept'        = 'application/json'
}
$null = Invoke-RestMethod `
    -Uri 'https://localise.biz/api/auth/verify' `
    -Method Post `
    -Headers $headers
$failures = [System.Collections.Generic.List[string]]::new()

foreach ($key in $removedKeys) {
    $encodedKey = [System.Uri]::EscapeDataString($key)
    $url = "https://localise.biz/api/assets/$encodedKey.json"
    $completed = $false

    for ($attempt = 1; $attempt -le 3 -and -not $completed; $attempt++) {
        try {
            Invoke-RestMethod -Uri $url -Method Delete -Headers $headers | Out-Null
            Write-Host "Deleted Loco asset: $key"
            $completed = $true
        } catch {
            $statusCode = $null
            if ($null -ne $_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }

            if ($statusCode -eq 404) {
                Write-Warning "Loco asset is already absent: $key"
                $completed = $true
                continue
            }

            $isTransient = $statusCode -eq 429 -or $statusCode -ge 500
            if ($isTransient -and $attempt -lt 3) {
                $delaySeconds = [math]::Pow(2, $attempt)
                Write-Warning "Transient failure deleting '$key' (HTTP $statusCode). Retrying in $delaySeconds seconds."
                Start-Sleep -Seconds $delaySeconds
                continue
            }

            $failures.Add("$key ($($_.Exception.Message))")
            break
        }
    }
}

if ($failures.Count -gt 0) {
    $failureSummary = $failures -join '; '
    throw "Some Loco assets could not be deleted: $failureSummary"
}

Write-Host "Successfully processed $($removedKeys.Count) removed Loco asset(s)."
