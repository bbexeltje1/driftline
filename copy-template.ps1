param(
    # Name of the folder to create, e.g. `copy-template.ps1 game-1`. Leave empty to fill the
    # folder you are standing in, which is the case where you already made the repository.
    [Parameter(Position = 0)][string]$Name = '',
    # Fill a folder at an exact path instead.
    [string]$Path = '',
    # In-game title. Defaults to the folder name, tidied up ("game-1" becomes "Game 1").
    [string]$DisplayName = '',
    # Copy from a template folder on disk instead of downloading it.
    [string]$TemplatePath = '',
    # Run `npm ci` so the test scripts work. Not needed to play.
    [switch]$Install,
    # Make the first commit for you.
    [switch]$Commit,
    [switch]$Push,
    # Connect to a repository that already exists on GitHub and push to it, e.g.
    #   copy-template.ps1 game-2 -Remote bbexeltje1/game2
    # The folder is filled from the template, so this never downloads the empty repository.
    [string]$Remote = '',
    # Empty the GitHub repository you point -Remote at. Required when it already has anything
    # in it, because a first commit cannot be pushed on top of unrelated history.
    [switch]$Replace,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 turns *any* stderr from a native program (git, npm, rojo) into a fatal
# error, even when the command succeeded. Without this, ordinary progress output aborts the run.
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

# ---------------------------------------------------------------------------------------
# copy-template.ps1 1.1
# Two ways to use it:
#   copy-template.ps1 game-1          creates C:\...\game-1 and fills it
#   (inside a repo) copy-template.ps1 fills the folder you are in
# Either way you get the one-command play loop, the tests and the CI. Then: .\scripts\play.ps1
# ---------------------------------------------------------------------------------------
$TemplateRepo = 'bbexeltje1/Newgame'
$TemplateBranch = 'arena/3885cdd1-newgame'
$TemplateFolder = 'template-rojo'

function Say([string]$Text) { Write-Host "   $Text" }
function Step([string]$Text) { Write-Host ''; Write-Host "== $Text" -ForegroundColor Cyan }
function Stop-Here([string]$Text) {
    Write-Host ''
    Write-Host "FAILED: $Text" -ForegroundColor Red
    exit 1
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Write-Text([string]$File, [string]$Text) { [System.IO.File]::WriteAllText($File, $Text, $utf8NoBom) }
function Read-Text([string]$File) { return [System.IO.File]::ReadAllText($File) }

Write-Host 'copy-template.ps1 1.1' -ForegroundColor DarkGray

# --- which folder --------------------------------------------------------------------------
Step 'Folder'
if (-not [string]::IsNullOrWhiteSpace($Name) -and -not [string]::IsNullOrWhiteSpace($Path)) {
    Stop-Here 'Pass either a folder name or -Path, not both.'
}

if (-not [string]::IsNullOrWhiteSpace($Name)) {
    if ($Name -match '[\\/:*?"<>|]') {
        Stop-Here ("The name '" + $Name + "' contains characters Windows does not allow in a folder name.")
    }
    # Beside this script, so it lands where you expect even when run from somewhere else.
    if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) { Stop-Here 'Run this script from a file, not from a pipeline.' }
    $Path = Join-Path $PSScriptRoot $Name
}
elseif ([string]::IsNullOrWhiteSpace($Path)) {
    $Path = (Get-Location).Path
}
$Path = [System.IO.Path]::GetFullPath($Path)

if (Test-Path -LiteralPath $Path -PathType Container) {
    Write-Host ("   exists    " + $Path)
}
else {
    # Making the folder is the whole point: nobody should have to `cd` somewhere that does not
    # exist yet. Windows protects some parents, so say so clearly if that happens.
    $parent = Split-Path $Path -Parent
    try {
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    catch {
        Stop-Here ("Windows will not let this script create the folder " + $Path + [Environment]::NewLine +
            "   " + $_.Exception.Message + [Environment]::NewLine +
            '   Pick somewhere you own, for example: -Path ' + (Join-Path $env:USERPROFILE ("projects\" + (Split-Path $Path -Leaf))))
    }
    Write-Host ("   created   " + $Path) -ForegroundColor Green
}

# "game 1" is not a valid npm name and spaces complicate tooling; tidy it to "game-1".
$folderName = Split-Path $Path -Leaf
$projectName = ($folderName.Trim() -replace '[^a-zA-Z0-9._-]+', '-').Trim('-', '.', '_').ToLowerInvariant()
if ([string]::IsNullOrWhiteSpace($projectName)) {
    Stop-Here ("Cannot make a project name out of the folder name '" + $folderName + "'.")
}
if ([string]::IsNullOrWhiteSpace($DisplayName)) {
    $DisplayName = ($projectName -replace '[-_]+', ' ')
    $DisplayName = (Get-Culture).TextInfo.ToTitleCase($DisplayName)
}

# Resolve -Remote now: a typo should fail before anything is copied, and the repository check
# below needs the URL. Pointing at a repository implies a commit and a push.
$remoteUrlWanted = ''
if (-not [string]::IsNullOrWhiteSpace($Remote)) {
    # Accept a URL, a local path (handy for testing and for a repo on a network drive), or the
    # owner/repository shorthand that people type for GitHub.
    $looksLikeUrl = ($Remote -match '^[a-zA-Z][a-zA-Z0-9+.-]*://') -or ($Remote -match '^git@')
    $looksLikePath = [System.IO.Path]::IsPathRooted($Remote) -or (Test-Path -LiteralPath $Remote)
    if ($looksLikeUrl -or $looksLikePath) {
        $remoteUrlWanted = $Remote
    }
    else {
        if ($Remote -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') {
            Stop-Here ("-Remote should look like owner/repository, for example bbexeltje1/game2. Got: " + $Remote)
        }
        $remoteUrlWanted = 'https://github.com/' + $Remote + '.git'
    }
    $Commit = $true
    $Push = $true
}
elseif ($Replace) {
    Stop-Here '-Replace only means something together with -Remote.'
}

$isGit = Test-Path -LiteralPath (Join-Path $Path '.git')
Say ("project   " + $projectName)
Say ("title     " + $DisplayName)
if ($isGit) { Say 'git       yes' } else { Say 'git       no (files only)' }

$templateItems = @('default.project.json', 'package.json', 'src', 'scripts', 'tests')
$already = @()
foreach ($item in $templateItems) {
    if (Test-Path -LiteralPath (Join-Path $Path $item)) { $already += $item }
}
if ($already.Count -gt 0 -and -not $Force) {
    Stop-Here ("That folder already has the template in it: " + ($already -join ', ') + [Environment]::NewLine +
        '   Nothing was changed. Add -Force to overwrite those files.')
}
if ($already.Count -gt 0) { Write-Host ("   overwriting: " + ($already -join ', ')) -ForegroundColor Yellow }

# --- get the template ----------------------------------------------------------------------
Step 'Getting the template'
$temp = ''
$source = ''
if (-not [string]::IsNullOrWhiteSpace($TemplatePath)) {
    if (-not (Test-Path -LiteralPath $TemplatePath)) { Stop-Here ("TemplatePath does not exist: " + $TemplatePath) }
    $source = [System.IO.Path]::GetFullPath($TemplatePath)
    Say ("using " + $source)
}
elseif ((Test-Path -LiteralPath (Join-Path $PSScriptRoot 'src')) -and
        (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'scripts'))) {
    # This file is sitting inside template-rojo, so there is nothing to download.
    $source = $PSScriptRoot
    Say ("using " + $source)
}
else {
    Say ("downloading from github.com/" + $TemplateRepo)
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ('copy-template-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $clone = Join-Path $temp 'repo'
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    & git clone --quiet --depth 1 --branch $TemplateBranch ("https://github.com/" + $TemplateRepo + ".git") $clone 2>$null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $clone)) {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
        Stop-Here ("Could not download the template from github.com/" + $TemplateRepo + [Environment]::NewLine +
            '   This machine must be signed in to GitHub (the template repository is private).' + [Environment]::NewLine +
            '     gh auth login' + [Environment]::NewLine +
            '   Or point at a copy you already have:' + [Environment]::NewLine +
            '     -TemplatePath (Join-Path $PWD "Newgame\template-rojo")')
    }
    $source = Join-Path $clone $TemplateFolder
    if (-not (Test-Path -LiteralPath $source)) {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
        Stop-Here ("The template folder '" + $TemplateFolder + "' was not in the download.")
    }
}

try {
    # --- copy ------------------------------------------------------------------------------
    Step 'Copying files'
    Copy-Item -Path (Join-Path $source '*') -Destination $Path -Recurse -Force
    # Wildcard copies skip dot-files on some PowerShell versions; copy those explicitly.
    foreach ($dotItem in @('.gitignore', '.gitattributes', '.github')) {
        $from = Join-Path $source $dotItem
        if (Test-Path -LiteralPath $from) {
            Copy-Item -Path $from -Destination (Join-Path $Path $dotItem) -Recurse -Force
        }
    }
    foreach ($junk in @('node_modules', 'build')) {
        $junkPath = Join-Path $Path $junk
        if (Test-Path -LiteralPath $junkPath) { Remove-Item -LiteralPath $junkPath -Recurse -Force }
    }

    $required = @(
        'default.project.json',
        'package.json',
        'package-lock.json',
        '.gitignore',
        'scripts/play.ps1',
        'scripts/build.ps1',
        'scripts/test.ps1',
        'tests/run-tests.mjs',
        'src/ReplicatedStorage/Shared/Config.luau',
        'src/ServerScriptService/Main.server.luau'
    )
    $missing = @()
    foreach ($file in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $Path $file))) { $missing += $file }
    }
    if ($missing.Count -gt 0) { Stop-Here ("The copy is incomplete. Missing: " + ($missing -join ', ')) }
    Say 'all template files present'

    # --- name it ---------------------------------------------------------------------------
    Step 'Naming the game'
    $projectFile = Join-Path $Path 'default.project.json'
    $projectText = Read-Text $projectFile
    if ($projectText -notmatch '"name"\s*:\s*"MyGame"') {
        Stop-Here 'default.project.json is not the template file (no "name": "MyGame").'
    }
    $projectReplacement = '"name": "' + $projectName + '"'
    Write-Text $projectFile ($projectText -replace '"name"\s*:\s*"MyGame"', $projectReplacement)

    $packageFile = Join-Path $Path 'package.json'
    $packageText = Read-Text $packageFile
    $packageReplacement = '"name": "' + $projectName + '"'
    Write-Text $packageFile ($packageText -replace '"name"\s*:\s*"roblox-rojo-template"', $packageReplacement)

    $configFile = Join-Path $Path 'src/ReplicatedStorage/Shared/Config.luau'
    $configText = Read-Text $configFile
    if ($configText -match 'displayName = "My Game"') {
        $configReplacement = 'displayName = "' + $DisplayName + '"'
        Write-Text $configFile ($configText -replace 'displayName = "My Game"', $configReplacement)
    }

    # Check the result now, so a broken file cannot reach Studio or GitHub.
    try {
        $parsed = Read-Text $projectFile | ConvertFrom-Json
        if ($parsed.name -ne $projectName) { throw 'the project name did not change' }
    }
    catch { Stop-Here ("The renamed default.project.json is not valid JSON: " + $_.Exception.Message) }
    $bytes = [System.IO.File]::ReadAllBytes($projectFile)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Stop-Here 'default.project.json was written with a byte-order mark, which Rojo cannot parse.'
    }
    Say ("project '" + $projectName + "', title '" + $DisplayName + "', no BOM")

    # --- what is on GitHub already ---------------------------------------------------------
    # An empty repository accepts the first push. One with its own initial commit does not,
    # until -Replace is passed -- so say that before building and committing.
    if (-not [string]::IsNullOrWhiteSpace($Remote) -and -not $Replace) {
        Step 'Checking the GitHub repository'
        $remoteHeads = (& git ls-remote --heads $remoteUrlWanted 2>$null)
        if ($LASTEXITCODE -ne 0) {
            Write-Host ('   could not read ' + $remoteUrlWanted + ' yet.') -ForegroundColor Yellow
            Write-Host '   If the push at the end is rejected, run again with -Replace.' -ForegroundColor Yellow
        }
        elseif ($null -ne $remoteHeads -and ($remoteHeads -join '') -match 'refs/heads/') {
            Write-Host ('   ' + $Remote + ' already has commits in it.') -ForegroundColor Yellow
            Write-Host '   Its first commit is unrelated to this one, so the push will be refused.' -ForegroundColor Yellow
            Write-Host '   Add -Replace to empty it and push this template, for example:' -ForegroundColor Yellow
            Write-Host ('     copy-template.ps1 ' + $projectName + ' -Remote ' + $Remote + ' -Replace') -ForegroundColor Yellow
            Stop-Here 'Nothing was changed. Re-run with -Replace if emptying that repository is what you want.'
        }
        else {
            Say 'empty, so the first push will be accepted'
        }
    }

    # --- optional steps --------------------------------------------------------------------
    if ($Install) {
        Step 'Installing test dependencies'
        Push-Location $Path
        try {
            & npm ci --silent 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host '   npm ci failed; trying npm install.' -ForegroundColor Yellow
                & npm install --silent 2>$null
            }
            if ($LASTEXITCODE -eq 0) { Say 'installed' }
            else { Write-Host '   install failed; the tests will not run until you fix it.' -ForegroundColor Yellow }
        }
        finally { Pop-Location }
    }

    if ($Commit -or $Push) {
        Step 'Committing'
        if (-not $isGit) {
            Push-Location $Path
            try {
                & git init --quiet 2>$null
                & git branch -M main 2>$null
            }
            finally { Pop-Location }
            Say 'created a git repository'
        }
        Push-Location $Path
        try {
            & git add -A 2>$null
            & git -c user.email='template@local' -c user.name='template' commit --quiet -m 'Add the Roblox game template' 2>$null
            if ($LASTEXITCODE -eq 0) { Say 'committed' } else { Write-Host '   nothing to commit' -ForegroundColor Yellow }

            if ($Push) {
                $branch = (& git rev-parse --abbrev-ref HEAD 2>$null)
                if ($null -ne $branch) { $branch = $branch.Trim() }
                if ([string]::IsNullOrWhiteSpace($branch) -or $branch -eq 'HEAD') { $branch = 'main' }

                if (-not [string]::IsNullOrWhiteSpace($remoteUrlWanted)) {
                    # `remote add` fails when origin already exists; then just repoint it.
                    & git remote add origin $remoteUrlWanted 2>$null
                    if ($LASTEXITCODE -ne 0) { & git remote set-url origin $remoteUrlWanted 2>$null }
                    Say ("remote    " + $remoteUrlWanted)
                }

                $hasRemote = $false
                $existing = (& git remote 2>$null)
                if ($null -ne $existing -and ($existing -join ' ') -match 'origin') { $hasRemote = $true }

                if (-not $hasRemote) {
                    Write-Host '   -Push needs a remote. Nothing was pushed.' -ForegroundColor Yellow
                    Write-Host ('     git remote add origin https://github.com/YOUR-ACCOUNT/' + $projectName + '.git')
                    Write-Host '     git push -u origin HEAD'
                }
                else {
                    if ($Replace) {
                        # The remote has commits of its own, so its history and this one share
                        # nothing. Rebuild this commit on an empty root: same files, no parent.
                        # The orphan branch needs a name that does not exist yet -- asking for
                        # `main` while on `main` fails and silently leaves the old history.
                        Say 'replacing the history of the remote (-Replace)'
                        $orphanBranch = 'template-root-' + [guid]::NewGuid().ToString('N').Substring(0, 6)
                        & git checkout --orphan $orphanBranch 2>&1 | Out-Null
                        if ($LASTEXITCODE -ne 0) { Stop-Here 'Could not start a fresh branch, so nothing was pushed.' }
                        & git add -A 2>$null
                        & git -c user.email='template@local' -c user.name='template' commit --quiet -m 'Add the Roblox game template' 2>$null
                        if ($LASTEXITCODE -ne 0) { Stop-Here 'Could not make the replacement commit, so nothing was pushed.' }
                        & git branch -M $branch 2>$null
                        # The files are already on disk; the index must match what is committed.
                        & git reset --mixed HEAD 2>$null | Out-Null
                        $replacedCount = (& git rev-list --count HEAD 2>$null)
                        if ($null -ne $replacedCount -and $replacedCount.Trim() -ne '1') {
                            Stop-Here ('The replacement history still has ' + $replacedCount.Trim() + ' commits; refusing to push.')
                        }
                        Say 'one commit, no earlier history'
                    }

                    & git push -u origin $branch --force 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Say ("pushed " + $branch)
                        $remoteUrlWanted = (& git remote get-url origin 2>$null)
                    }
                    else {
                        Write-Host '   push was rejected.' -ForegroundColor Yellow
                        if (-not $Replace) {
                            Write-Host '   The GitHub repository probably already has commits in it. Either:' -ForegroundColor Yellow
                            Write-Host ('     run again with -Replace   (empties ' + $Remote + ' and pushes this template)') -ForegroundColor Yellow
                            Write-Host '     or delete the repository on GitHub and let it be created fresh.' -ForegroundColor Yellow
                        }
                        else {
                            Write-Host '   Check that gh is signed in and that you own the repository:' -ForegroundColor Yellow
                            Write-Host '     gh auth status' -ForegroundColor Yellow
                        }
                    }
                }
            }
        }
        finally { Pop-Location }
    }

    # --- what next -------------------------------------------------------------------------
    Write-Host ''
    Write-Host ("Ready: " + $Path) -ForegroundColor Green
    Write-Host ''
    Write-Host 'Next:'
    Write-Host ('  cd "' + $Path + '"')
    Write-Host '  .\scripts\play.ps1'
    Write-Host ''
    Write-Host 'That builds the place and opens it in Studio. It works before you make a git repository.'
}
finally {
    if (-not [string]::IsNullOrWhiteSpace($temp) -and (Test-Path -LiteralPath $temp)) {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
