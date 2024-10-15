###Set working firectory to source code
$sourceBranch = $env:sourceBranch
$translationsBranch = $env:translationsBranch

if (!($sourceBranch.Length -gt 0) -or !($translationsBranch.Length -gt 0)) {
    Write-Error "Branches are not set."
    exit 1
}
$changesDetected = $env:changesDetected

if ($changesDetected -eq 'true') {
    $commitMessage = "Loco updates " + (Get-Date -UFormat "%Y.%m.%d")
    git config user.email "noreply@flipdish.com"
    git config user.name "Github Actions"
    git status
    git add -A
    Write-Host "Committing changes with message:" $commitMessage
    git commit -m $commitMessage
    Write-Host "Pushing changes to:" $translationsBranch
    git push origin $translationsBranch
}