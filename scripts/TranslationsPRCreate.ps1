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

    $command = "gh pr create --title '$pullRequestTitle' --head $translationsBranch --base $sourceBranch --repo $repositoryUri --body 'This PR is created by GitHub Actions to update translations files.'"
    
    if (-not [string]::IsNullOrEmpty($env:reviewer)) {
        $command += " --reviewer $env:reviewer"
    }

    if ($env:draft -eq "true") {
        $command += " --draft"
    }
    
    $pullRequestCreated = Invoke-Expression $command
    
    if ($debugInfo -eq 'true') {
        Write-Host "Pull Request Created:" $pullRequestCreated
    }

    if ($env:automerge -eq "true") {
        gh pr merge $pullRequestCreated --auto --delete-branch --squash
    }

    if ($env:review -eq "true") {
        gh pr review $pullRequestCreated --approve --body "Approved by GitHub Actions to update translations files."
    }

}