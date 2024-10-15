###Set working firectory to source code
###Provide GH_TOKEN variable

$debugInfo = $env:debugInfo

$repositoryId = $env:repositoryId
$repositoryUri = "https://github.com/" + $repositoryId
Write-Host "Repository URL:" $repositoryUri

$mainBranch = $env:mainBranch
Write-Host "Checking for Pull Requests targeting $mainBranch branch..."

$ghResponse = gh pr list --state open --json title,headRefName,baseRefName --repo $repositoryUri
$pullRequests = $ghResponse | ConvertFrom-Json

if ($null -ne $pullRequests -and $pullRequests.Count -gt 0) {
    Write-Host "Available Pull Requests:"
    foreach ($pr in $pullRequests) {
        Write-Host "Title: $($pr.title), BaseRefName: $($pr.baseRefName)"
    }

    $pullRequest = $pullRequests | Where-Object { 
        $_.title -match '^\[LANG\] Loco updates' -and $_.baseRefName -eq $mainBranch 
    }

    if ($null -eq $pullRequest) {
        Write-Host "No matching pull requests found."
    }
} else {
    Write-Host "No pull requests found."
}

if ($pullRequest.count) {
    if ($pullRequest.count -ne 1) {
        Write-Host "There are more than one Pull Requests for Language Update. Latest updated will be used."
        if ($debugInfo -eq 'true') { Write-Host "Pull Requests Titles:"($pullRequest.title | ConvertTo-Json -Depth 1) }
        $pullRequestLatest = $pullRequest | Foreach-Object { $_.updated_at = [DateTime]$_.updated_at; $_ } |
        Group-Object Computer |
        Foreach-Object { $_.Group | Sort-Object updated_at | Select-Object -Last 1 }
    }
    else { $pullRequestLatest = $pullRequest }

    if ($debugInfo -eq 'true') { Write-Host "Pull Request:"($pullRequestLatest | ConvertTo-Json -Depth 1) }
    Write-Host "Pull Request branch will be used as a source branch."
    Write-Host "Pull Request Title:" $pullRequestLatest.title
    $sourceBranch = $pullRequestLatest.baseRefName
    $translationsBranch = $pullRequestLatest.headRefName
    $createPullRequest = 'false'
} else {
    Write-Host "No Pull Requests found. Will use main branch as a source branch."
    $sourceBranch = $env:mainBranch
    $translationsBranch = "loco_updates_" + (Get-Date -UFormat "%Y_%m_%d")
    $createPullRequest = 'true'
}

Write-Host "Source Branch:" $sourceBranch
Write-Host "Translations Branch:" $translationsBranch
Write-Host "Create PR:" $createPullRequest

"sourceBranch=$sourceBranch" | Out-File -Append -FilePath $env:GITHUB_OUTPUT
"translationsBranch=$translationsBranch" | Out-File -Append -FilePath $env:GITHUB_OUTPUT
"createPullRequest=$createPullRequest" | Out-File -Append -FilePath $env:GITHUB_OUTPUT