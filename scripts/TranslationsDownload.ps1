###Add environment variable: locoExportKey
###Add environment variable: langs - 'en,uk-UA' as example
###Add environment variable: tmpFolder - 'tmp' by default
###Add environment variable: format
###Add environment variable: noFolding - 'true' or 'false'
###Add environment variable: convert - 'true' or 'false'
###Set working directory to source code

function CreateTmpFolder([String] $tmpFolder) {
    if ([string]::IsNullOrEmpty($tmpFolder)) {
        $tmpFolder = "tmp"
    }
    
    if (Test-Path "$tmpFolder") {
        Write-Host "Removing $tmpFolder..."
        Remove-Item -Recurse -Force "$tmpFolder"
    }
    Write-Host "Creating $tmpFolder..."
    New-Item -ItemType Directory -Path "$tmpFolder" 
}

function DownloadResx([String] $tmpFolder, [String] $lang, [String] $locoExportKey) {
    $url = "https://localise.biz/api/export/locale/{0}.resx?status=translated&key={1}" -f $lang, $locoExportKey

    if ($lang -eq "en") { $fileName = "Resources.resx" } else { $fileName = "Resources.{0}.resx" -f $lang }

    $path = "{0}\{1}" -f $tmpFolder, $fileName

    "Downloading to $path..."
    Invoke-WebRequest -Uri $url -OutFile $path

    $tmppath = $path + ".tmp"
    "Removing Loco comments from $path"
    Get-Content $path | Where-Object { $_ -notmatch "^  Exported at" } | Where-Object { $_ -notmatch "^  Exported by" } | Set-Content $tmppath
    Write-Host $path
    Remove-Item $path
    Rename-Item -Path $tmppath -NewName $fileName
}

function DownloadJson([String] $tmpFolder, [String] $lang, [String] $locoExportKey, [String]$noFolding) {
    if ($noFolding -eq 'true') {
        $url = "https://localise.biz/api/export/locale/{0}.json?status=translated&key={1}&no-folding=true" -f $lang, $locoExportKey
    }
    else {
        $url = "https://localise.biz/api/export/locale/{0}.json?status=translated&key={1}" -f $lang, $locoExportKey
    }

    $filesExtensionLength = $env:filesExtension.Length

    if ($filesExtensionLength -gt 0) { $fileExtension = $env:filesExtension } else { $fileExtension = "json" }
    if (($env:languagePostfixInNames -eq "true") -and ($lang -ne "en")) {
        $langToUpperCase = $lang.ToUpper()
        $fileName = "{0}_{1}.{2}" -f $lang, $langToUpperCase, $fileExtension
    }
    else {
        $fileName = "{0}.{1}" -f $lang, $fileExtension
    }

    $path = "{0}\{1}" -f $tmpFolder, $fileName

    "Downloading to $path..."
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing | Select-Object -ExpandProperty Content

    if ($env:convert -eq "true") {
        Write-Host "Formatting and sorting JSON output..."
        # Extract keys and values from original JSON string to preserve case-sensitive keys
        $keyValueMatches = [regex]::Matches($response, '"([^"]+)":\s*"([^"]*)"')
        
        # Build JSON string manually to avoid any PowerShell JSON conversion issues
        $jsonParts = @()
        foreach ($match in $keyValueMatches) {
            $key = $match.Groups[1].Value
            $value = $match.Groups[2].Value
            $jsonParts += "`"$key`": {" + [Environment]::NewLine + "    `"value`": `"$value`"" + [Environment]::NewLine + "  }"
        }
        $finalJson = "{" + [Environment]::NewLine + "  " + ($jsonParts -join ("," + [Environment]::NewLine + "  ")) + [Environment]::NewLine + "}"
        $finalJson | Out-File -Encoding utf8 $path
    }
    else {
        $response | Out-File -Encoding utf8 $path
    }
}
function DownloadXML([String] $tmpFolder, [String] $lang, [String] $locoExportKey) {
    $url = "https://localise.biz/api/export/locale/{0}.xml?status=translated&key={1}&format=android" -f $lang, $locoExportKey

    $fileFolder = "values-" + $lang
    $fileName = "strings.xml"

    Write-Host "Downloading translations for xml"
    #make sure the folder exists before downloading, create it if it doesn't
    if (!(Test-Path "$tmpFolder/$fileFolder")) {
        New-Item -ItemType Directory -Path "$tmpFolder/$fileFolder"
        Write-Host "Creating $tmpFolder/$fileFolder..."
    }

    $path = "{0}\{1}\{2}" -f $tmpFolder, $fileFolder, $fileName

    "Downloading to $path..."
    Invoke-WebRequest -Uri $url -OutFile $path

    $tmppath = $path + ".tmp"
    "Removing Loco comments from $path"
    Get-Content $path | Where-Object { $_ -notmatch "^ Exported at:" } | Where-Object { $_ -notmatch "^ Exported by:" } | Set-Content $tmppath
    Write-Host $path
    Remove-Item $path
    Rename-Item -Path $tmppath -NewName $fileName

    if ($lang -eq "en") {
        if (!(Test-Path "$tmpFolder/values")) {
            New-Item -ItemType Directory -Path "$tmpFolder/values"
            Write-Host "Creating $tmpFolder/values..."
        }
        "Copying to $tmpFolder/values..."
        $path = "{0}\{1}\{2}" -f $tmpFolder, "values", $fileName
        Copy-Item -Path "$tmpFolder\values-$lang\$fileName" -Destination "$tmpFolder\values\$fileName"
    }
}

function DownloadLproj([String] $tmpFolder, [String] $lang, [String] $locoExportKey) {
    $folderName = "{0}.lproj" -f $lang

    if (!(Test-Path "$tmpFolder/$folderName")) {
        New-Item -ItemType Directory -Path "$tmpFolder/$folderName"
        Write-Host "Creating $tmpFolder/$folderName..."
    }

    $fileNameStrings = "Localizable.strings"
    $fileNameInfoPlist = "InfoPlist.strings"

    $urlStrings = "https://localise.biz/api/export/locale/{0}.strings?status=translated&charset=utf8&key={1}" -f $lang, $locoExportKey
    $urlInfoPlist = "https://localise.biz/api/export/locale/{0}.plist?status=translated&charset=utf8&key={1}" -f $lang, $locoExportKey


    $pathStrings = "{0}\{1}\{2}" -f $tmpFolder, $folderName, $fileNameStrings
    $pathInfoPlist = "{0}\{1}\{2}" -f $tmpFolder, $folderName, $fileNameInfoPlist

    "Downloading $fileNameStrings and $fileNameInfoPlist to $folderName..."
    Invoke-WebRequest -Uri $urlStrings -OutFile $pathStrings
    Invoke-WebRequest -Uri $urlInfoPlist -OutFile $pathInfoPlist
}

function DownloadResxs([String] $tmpFolder, [String] $locoExportKey, [String[]] $langs) {    
    Foreach ($lang in $langs) {
        DownloadResx $tmpFolder $lang $locoExportKey
    }
}

function DownloadJsons([String] $tmpFolder, [String] $locoExportKey, [String[]] $langs, [String] $noFolding) {    
    Foreach ($lang in $langs) {
        DownloadJson $tmpFolder $lang $locoExportKey $noFolding
    }
}

function DownloadXMLs([String] $tmpFolder, [String] $locoExportKey, [String[]] $langs) {    
    Foreach ($lang in $langs) {
        DownloadXML $tmpFolder $lang $locoExportKey
    }
}

function DownloadLprojs([String] $tmpFolder, [String] $locoExportKey, [String[]] $langs) {    
    Foreach ($lang in $langs) {
        DownloadLproj $tmpFolder $lang $locoExportKey
    }
}

$tmpFolder = $env:tmpFolder
CreateTmpFolder $tmpFolder

$langs = $env:langs -split ","
$noFolding = $env:nofolding
$format = $env:format
$filesExtension = $env:filesExtension
$languagePostfixInNames = $env:languagePostfixInNames

switch ($format) {
    "resx" {
        Write-Host "Downloading translations for $langs..."
        DownloadResxs $tmpFolder $env:locoExportKey $langs
    }
    "json" {
        Write-Host "Downloading translations for $langs..."
        DownloadJsons $tmpFolder $env:locoExportKey $langs $noFolding
    }
    "lproj" {
        Write-Host "Downloading translations for $langs..."
        DownloadLprojs $tmpFolder $env:locoExportKey $langs
    }
    "xml" {
        Write-Host "Downloading translations for $langs..."
        DownloadXMLs $tmpFolder $env:locoExportKey $langs
    }
    default {
        Write-Host "Unsupported format: $format"
        Write-Host "Supported formats: resx, json, lproj"
        exit 1
    }
}
