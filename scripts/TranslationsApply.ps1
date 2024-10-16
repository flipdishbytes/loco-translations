$tmpFolder = $env:tmpFolder
$targetFolder = $env:targetFolder

if (([string]::IsNullOrEmpty($targetFolder)) -or ([string]::IsNullOrEmpty($tmpFolder))) {
    Write-Error "Folders are not set."
    exit 1
}

Write-Host "Moving all folders and files recursively from $tmpFolder to $targetFolder..."
Move-Item -Path "$tmpFolder\*" -Destination $targetFolder -Force

if (Test-Path "$tmpFolder") {
    Write-Host "Removing $tmpFolder..."
    Remove-Item -Recurse -Force "$tmpFolder"
}

if (git status --porcelain | Where-Object { $_ -match '^\?\?' }) {
    Write-Host 'Untracked files exist.'
    $changesDetected = 'true'
}
elseif (git status --porcelain | Where-Object { $_ -notmatch '^\?\?' }) {
    Write-Host 'Uncommitted changes.'
    $changesDetected = 'true'
}
else {
    $changesDetected = 'false'
    Write-Host 'Tree is clean. Nothing to commit.'
}

Write-Host "Changes Detected:" $changesDetected

"changesDetected=$changesDetected" | Out-File -Append -FilePath $env:GITHUB_OUTPUT