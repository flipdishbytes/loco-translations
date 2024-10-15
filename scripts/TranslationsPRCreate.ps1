###Provide GH_TOKEN variable

$debugInfo = $env:debugInfo

$repositoryId = $env:repositoryId
$repositoryUri = "https://github.com/" + $repositoryId
Write-Host "Repository URL:" $repositoryUri

$createPullRequest = $env:createPullRequest
$translationsBranch = $env:translationsBranch
$sourceBranch = $env:sourceBranch

if ($createPullRequest -eq 'true') {
    $pullRequestTitle = "[LANG] Loco updates " + (Get-Date -UFormat "%Y.%m.%d")
    Write-Host "Pull Request title:" $pullRequestTitle
    Write-Host "Translations Branch:" $translationsBranch
    Write-Host "Source Branch:" $sourceBranch
    
    if ($env:reviewer.Length -eq 0) {
        $pullRequestCreated = gh pr create --title $pullRequestTitle --head $translationsBranch --base $sourceBranch --repo $repositoryUri --body "This PR is created by GitHub Actions to update translations files."
    }
    else {
        $pullRequestCreated = gh pr create --title $pullRequestTitle --head $translationsBranch --base $sourceBranch --repo $repositoryUri --body "This PR is created by GitHub Actions to update translations files." --reviewer $env:reviewer
    }
    
    if ($debugInfo -eq 'true') {
        Write-Host "Pull Request Created:"($pullRequestCreated | ConvertTo-Json -Depth 1)
    }
}