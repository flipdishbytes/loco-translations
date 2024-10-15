###Add environment variable: locoExportKey
###Add environment variable: langs - 'en,uk-UA' as example
###Add environment variable: tmpFolder - 'tmp' by default
###Add environment variable: format
###Set working firectory to source code

function CreateTmpFolder([String] $tmpFolder){
    if ($tmpFolder.Length -eq 0) {
        $tmpFolder = "tmp"
    }
    
    if (Test-Path "$tmpFolder") {
        Write-Host "Removing $tmpFolder..."
        Remove-Item -Recurse -Force "$tmpFolder"
    }
    Write-Host "Creating $tmpFolder..."
    New-Item -ItemType Directory -Path "$tmpFolder" 
}


function DownloadResx([String] $tmpFolder,[String] $lang,[String] $locoExportKey){
    $url = "https://localise.biz/api/export/locale/{0}.resx?status=translated&key={1}" -f $lang, $locoExportKey

    if($lang -eq "en") { $fileName = "Resources.resx" } else { $fileName = "Resources.{0}.resx" -f $lang }

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

function DownloadJson([String] $tmpFolder,[String] $lang,[String] $locoExportKey){
    $url = "https://localise.biz/api/export/locale/{0}.json?status=translated&key={1}" -f $lang, $locoExportKey

    $fileName =  "{0}.json" -f $lang

    $path = "{0}\{1}" -f $tmpFolder, $fileName

    "Downloading to $path..."
    Invoke-WebRequest -Uri $url -OutFile $path
}

function DownloadLproj([String] $tmpFolder,[String] $lang,[String] $locoExportKey){
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

function DownloadResxs([String] $tmpFolder, [String] $locoExportKey, [String[]] $langs){    
    Foreach ($lang in $langs)
    {
        DownloadResx $tmpFolder $lang $locoExportKey
    }
}

function DownloadJsons([String] $tmpFolder, [String] $locoExportKey, [String[]] $langs){    
    Foreach ($lang in $langs)
    {
        DownloadJson $tmpFolder $lang $locoExportKey
    }
}

function DownloadLprojs([String] $tmpFolder, [String] $locoExportKey, [String[]] $langs){    
    Foreach ($lang in $langs)
    {
        DownloadLproj $tmpFolder $lang $locoExportKey
    }
}

$tmpFolder = $env:tmpFolder
CreateTmpFolder $tmpFolder

$langs = $env:langs -split ","
Write-Host "Downloading translations for $langs..."

$format = $env:format
switch ($format) {
    "resx" {
        DownloadResxs $tmpFolder $env:locoExportKey $langs
    }
    "json" {
        DownloadJsons $tmpFolder $env:locoExportKey $langs
    }
    "lproj" {
        DownloadLprojs $tmpFolder $env:locoExportKey $langs
    }
    default {
        Write-Host "Unsupported format: $format"
        Write-Host "Supported formats: resx, json, lproj"
        exit 1
    }
}
