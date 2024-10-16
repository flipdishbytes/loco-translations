# Read the folder path from environment variable
$folderPath = $env:folderPath

# Check if the folder path is null or empty
if ([string]::IsNullOrWhiteSpace($folderPath)) {
    Write-Error "Error: folderPath environment variable is not set or empty."
    exit 1
}

# Remove all files in the folder recursively, including hidden files
Get-ChildItem -Path $folderPath -Recurse -Force -File | ForEach-Object {
    Remove-Item -Path $_.FullName -Force
}

# Remove all directories in the folder recursively, including hidden directories
Get-ChildItem -Path $folderPath -Recurse -Force -Directory | ForEach-Object {
    Remove-Item -Path $_.FullName -Recurse -Force
}
