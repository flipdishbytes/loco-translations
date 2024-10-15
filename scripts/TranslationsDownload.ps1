###Add environment variable: locoExportKey
###Add environment variable: langs - 'en-GB,uk-UA' by default
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

    if($lang -eq "en"){
        $fileName = "Resources.resx";
    }
    $fileName =  "Resources.{0}.resx" -f $lang

    $path = "{0}\{1}" -f $tmpFolder, $fileName

    "Downloading to $path..."
    Invoke-WebRequest -Uri $url -OutFile $path

    "Removing Loco comments from $path..."
    Get-Content $path | Where-Object { $_ -notmatch "^  Exported at" -and $_ -notmatch "^  Exported by" } | Set-Content $path
}

function DownloadResxs([String] $tmpFolder, [String] $locoExportKey, [String[]] $langs){    
    Foreach ($lang in $langs)
    {
        DownloadResx $tmpFolder $lang $locoExportKey
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
    default {
        Write-Host "Unsupported format: $format"
        exit 1
    }
}
