# Seed/import translations from a local JSON file to Loco (localise.biz).
# Ensures all keys from the file are present in Loco (ignore-existing skips updating existing).
#
# Environment variables:
#   locoWriteKey   - Loco API write/full-access key (https://localise.biz -> Project -> Developer tools)
#   lang           - Target locale (e.g. 'en')
#   sourceFile     - Full path to the JSON file to import (e.g. en.json)
#   caseSensetive  - Use case-sensitive JSON key handling when set to 'true'

$locoWriteKey = $env:locoWriteKey
$lang = $env:lang
$sourceFile = $env:sourceFile
$caseSensetive = $env:caseSensetive -eq 'true'

if ([string]::IsNullOrWhiteSpace($locoWriteKey)) {
    Write-Error "locoWriteKey is not set."
    exit 1
}
if ([string]::IsNullOrWhiteSpace($lang)) {
    Write-Error "lang is not set."
    exit 1
}
if ([string]::IsNullOrWhiteSpace($sourceFile)) {
    Write-Error "sourceFile is not set."
    exit 1
}

if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
    Write-Error "Source file not found: $sourceFile"
    exit 1
}

Write-Host "Seeding translations from $sourceFile to Loco (locale: $lang)..."

$raw = Get-Content -LiteralPath $sourceFile -Raw -Encoding utf8

if ($caseSensetive) {
    # PSCustomObject properties are case-insensitive, but JSON and Loco asset
    # IDs are case-sensitive. Use an ordinal dictionary so keys such as
    # "Example_Key" and "Example_key" can coexist.
    $data = $raw | ConvertFrom-Json -AsHashtable
    $seedData = [System.Collections.Generic.Dictionary[string, object]]::new(
        [System.StringComparer]::Ordinal
    )

    foreach ($entry in $data.GetEnumerator()) {
        $key = $entry.Key
        $val = $entry.Value
        if ($val -is [System.Collections.IDictionary] -and $val.Contains('value')) {
            $seedData[$key] = $val['value']
        } elseif ($val -is [string]) {
            $seedData[$key] = $val
        } else {
            # Fallback: coerce to string (e.g. number or nested object)
            $seedData[$key] = $val.ToString()
        }
    }
} else {
    # Preserve the original conversion for backwards compatibility.
    $data = $raw | ConvertFrom-Json
    $seedData = @{}

    foreach ($entry in $data.PSObject.Properties) {
        $key = $entry.Name
        $val = $entry.Value
        if ($val -is [System.Management.Automation.PSCustomObject] -and $null -ne $val.PSObject.Properties['value']) {
            $seedData[$key] = $val.value
        } elseif ($val -is [string]) {
            $seedData[$key] = $val
        } else {
            # Fallback: coerce to string (e.g. number or nested object)
            $seedData[$key] = $val.ToString()
        }
    }
}

$body = $seedData | ConvertTo-Json -Compress
$localeEncoded = [System.Uri]::EscapeDataString($lang)
$query = "index=id&locale=$localeEncoded&ignore-existing=true"
$url = "https://localise.biz/api/import/json?$query"

$headers = @{
    'Authorization' = "Loco $locoWriteKey"
    'Content-Type'  = 'application/json'
}

try {
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType 'application/json; charset=utf-8'
    Write-Host "Success:" ($response | ConvertTo-Json -Depth 5)
} catch {
    Write-Error "Import failed: $($_.Exception.Message)"
    exit 1
}
