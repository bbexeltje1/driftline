param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Name,
    [string]$DisplayName = '',
    # Where to put the project. Defaults to a folder beside this script, so running
    #   C:\Users\you\new-game.ps1 -Name my-game
    # produces C:\Users\you\my-game
    [string]$Path = '',
    # Copy the template from a folder you already have instead of downloading it. Mainly for
    # CI and for working offline; normal use leaves this empty.
    [string]$TemplatePath = '',
    # GitHub repository name. Defaults to the project name.
    [string]$RepoName = '',
    [switch]$NoRepo,
    [switch]$Public,
    [switch]$NoPush,
    [switch]$NoPlay,
    [switch]$SkipInstall,
    [switch]$Fresh
)
$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 turns *any* native-program stderr output into a fatal error
# (NativeCommandError), and git writes hints and progress there even on success.
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}
Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------------------
# new-game.ps1 1.1
# One command: create the folder, fill it with the Roblox template, install dependencies,
# build the place, open Studio, create the GitHub repository and push. Works from any
# directory, on Windows PowerShell 5.1.
# ---------------------------------------------------------------------------------------
$Version = '1.1'
$TemplateRepo = 'bbexeltje1/Newgame'
$TemplateBranch = 'arena/3885cdd1-newgame'
$TemplateFolder = 'template-rojo'

function Step([string]$Text) { Write-Host ''; Write-Host "== $Text" -ForegroundColor Cyan }
function Info([string]$Text) { Write-Host "   $Text" }
function Warn([string]$Text) { Write-Host "   $Text" -ForegroundColor Yellow }
function Fail([string]$Text) {
    Write-Host ''
    Write-Host "FAILED: $Text" -ForegroundColor Red
    exit 1
}

# UTF-8 without a byte-order mark. Windows PowerShell's `-Encoding utf8` writes a BOM, and
# Rojo rejects a project file that starts with one ("Failed to parse JSONC").
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Write-Text([string]$File, [string]$Text) {
    [System.IO.File]::WriteAllText($File, $Text, $utf8NoBom)
}
function Read-Text([string]$File) { return [System.IO.File]::ReadAllText($File) }

Write-Host "new-game.ps1 $Version" -ForegroundColor DarkGray

# --- preflight ---------------------------------------------------------------------------
Step 'Checking what is installed'
$missing = @()
foreach ($tool in @('git', 'node', 'npm', 'rojo')) {
    if ($null -eq (Get-Command $tool -ErrorAction SilentlyContinue)) { $missing += $tool }
    else { Info "$tool  ok" }
}
$hasGh = $null -ne (Get-Command 'gh' -ErrorAction SilentlyContinue)
if ($hasGh) { Info 'gh  ok' }
else { Warn 'gh (GitHub CLI) is missing: the repository step will be skipped. Install from https://cli.github.com' }
if ($missing.Count -gt 0) {
    Fail ("Missing required tools: " + ($missing -join ', ') + [Environment]::NewLine +
        '   git  https://git-scm.com/download/win' + [Environment]::NewLine +
        '   node https://nodejs.org (Node 22+)' + [Environment]::NewLine +
        '   rojo https://rojo.space (7.7.1+)')
}

# --- where the project goes --------------------------------------------------------------
Step 'Working out where the project goes'
if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) { Fail 'Run this script from a file, not a pipeline.' }
$scriptRoot = $PSScriptRoot.TrimEnd([char[]]@('\', '/'))
if ($scriptRoot -match '^[A-Za-z]:$') { $scriptRoot = $scriptRoot + '\' }

if ([string]::IsNullOrWhiteSpace($Path)) {
    # Beside the script: C:\Users\you\new-game.ps1 -Name my-game -> C:\Users\you\my-game
    $Path = Join-Path $scriptRoot $Name
}
elseif (-not [System.IO.Path]::IsPathRooted($Path)) {
    # A relative -Path is resolved against the folder this script lives in, never the shell's
    # current directory: "run it from anywhere" must mean exactly that.
    $Path = Join-Path $scriptRoot $Path
}
if ([string]::IsNullOrWhiteSpace($Path)) { Fail 'The destination path resolved to nothing.' }
$Path = [System.IO.Path]::GetFullPath($Path)
Info "project   $Path"
Info "template  $TemplateRepo ($TemplateBranch/$TemplateFolder)"

if ($Name -notmatch '^[a-zA-Z0-9._-]+$') { Fail "Use letters, digits, dots, dashes or underscores: '$Name'" }
if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = $Name }
if ([string]::IsNullOrWhiteSpace($RepoName)) { $RepoName = $Name }

if (Test-Path -LiteralPath $Path) {
    $existing = @(Get-ChildItem -LiteralPath $Path -Force)
    if ($existing.Count -gt 0) {
        if (-not $Fresh) {
            $hasGit = Test-Path -LiteralPath (Join-Path $Path '.git')
            $advice = if ($hasGit) {
                '   That folder is already a git repository. To fill it with the template instead:' + [Environment]::NewLine +
                '     .\fill-repository.ps1 -RepositoryPath "' + $Path + '" -Commit -Push'
            }
            else {
                '   Delete it, or add -Fresh to replace it.'
            }
            Fail ("$Path already exists and is not empty." + [Environment]::NewLine + $advice)
        }
        Warn 'Replacing the existing folder (-Fresh).'
        try { Remove-Item -LiteralPath $Path -Recurse -Force }
        catch { Fail "Could not remove $Path : $($_.Exception.Message)" }
    }
}

$parent = Split-Path $Path -Parent
if ([string]::IsNullOrWhiteSpace($parent)) { Fail "Could not work out a parent folder for '$Path'." }
if (-not (Test-Path -LiteralPath $parent)) {
    try { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    catch { Fail "Cannot create the folder $parent : $($_.Exception.Message)" }
}
# Prove the destination is writable now, before downloading anything, so a permissions
# problem is reported as a permissions problem instead of a mysterious failure later.
try { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
catch {
    Fail ("Windows will not let this script create the folder $Path" + [Environment]::NewLine +
        "   $($_.Exception.Message)" + [Environment]::NewLine +
        '   Pass -Path with somewhere you own, for example:' + [Environment]::NewLine +
        '   -Path ' + (Join-Path $scriptRoot $Name))
}

# --- fetch the template ------------------------------------------------------------------
Step 'Fetching the template'
if (-not [string]::IsNullOrWhiteSpace($TemplatePath)) {
    if (-not (Test-Path -LiteralPath $TemplatePath)) { Fail "TemplatePath does not exist: $TemplatePath" }
    Copy-Item -Path (Join-Path $TemplatePath '*') -Destination $Path -Recurse -Force
    foreach ($dotItem in @('.gitignore', '.gitattributes', '.github')) {
        $from = Join-Path $TemplatePath $dotItem
        if ((Test-Path -LiteralPath $from) -and -not (Test-Path -LiteralPath (Join-Path $Path $dotItem))) {
            Copy-Item -Path $from -Destination (Join-Path $Path $dotItem) -Recurse -Force
        }
    }
    foreach ($junk in @('node_modules', 'build', '.git')) {
        $junkPath = Join-Path $Path $junk
        if (Test-Path -LiteralPath $junkPath) { Remove-Item -LiteralPath $junkPath -Recurse -Force }
    }
    Info "template copied from $TemplatePath"
}
else {
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ('new-game-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $repo = Join-Path $temp 'repo'
    try {
        New-Item -ItemType Directory -Path $temp -Force | Out-Null
        # A shallow clone of one branch is the reliable way to get a subfolder out of a remote
        # repository; `git archive --remote` needs server-side upload-archive enabled.
        $cloneOutput = & git -c core.askPass= clone --quiet --depth 1 --branch $TemplateBranch "https://github.com/$TemplateRepo.git" $repo 2>&1
        if ($LASTEXITCODE -ne 0) {
            $hint = ''
            if (($cloneOutput -join ' ') -match 'could not read Username|Authentication failed|terminal prompts disabled') {
                $hint = [Environment]::NewLine +
                    '   The template repository is private, so this machine must be signed in to GitHub.' + [Environment]::NewLine +
                    '   Fix it with one of:' + [Environment]::NewLine +
                    '     gh auth login            (easiest: install the GitHub CLI first)' + [Environment]::NewLine +
                    '     git config --global credential.helper manager' + [Environment]::NewLine +
                    '   Or point at a template folder you already have, for example:' + [Environment]::NewLine +
                    '     -TemplatePath C:\Users\exelt\Newgame\template-rojo'
            }
            Fail ("Could not download the template from https://github.com/$TemplateRepo" + [Environment]::NewLine +
                "   $cloneOutput" + $hint)
        }
        $templateSource = Join-Path $repo $TemplateFolder
        if (-not (Test-Path -LiteralPath $templateSource)) {
            Fail "The template folder '$TemplateFolder' is not in $TemplateRepo ($TemplateBranch)."
        }
        Copy-Item -Path (Join-Path $templateSource '*') -Destination $Path -Recurse -Force
        # Wildcard copies are inconsistent about dot-files on older PowerShell builds; copy these
        # explicitly so the repository rules and the CI workflow always arrive.
        foreach ($dotItem in @('.gitignore', '.gitattributes', '.github')) {
            $from = Join-Path $templateSource $dotItem
            $to = Join-Path $Path $dotItem
            if ((Test-Path -LiteralPath $from) -and -not (Test-Path -LiteralPath $to)) {
                Copy-Item -Path $from -Destination $to -Recurse -Force
            }
        }
        # Nothing machine-specific may come along for the ride.
        foreach ($junk in @('node_modules', 'build', '.git')) {
            $junkPath = Join-Path $Path $junk
            if (Test-Path -LiteralPath $junkPath) { Remove-Item -LiteralPath $junkPath -Recurse -Force }
        }
    }
    finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# The copy must be complete before anything is renamed or committed.
$required = @(
    'default.project.json',
    'package.json',
    'package-lock.json',
    '.gitignore',
    'scripts/build.ps1',
    'scripts/play.ps1',
    'scripts/test.ps1',
    'tests/run-tests.mjs',
    'src/ReplicatedStorage/Shared/Config.luau',
    'src/ServerScriptService/Main.server.luau'
)
$missingFiles = @()
foreach ($requiredFile in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $Path $requiredFile))) { $missingFiles += $requiredFile }
}
if ($missingFiles.Count -gt 0) {
    Fail ("The template came down incomplete. Missing: " + ($missingFiles -join ', '))
}
Info 'template copied and checked'

# --- rename ------------------------------------------------------------------------------
Step 'Naming the project'
$projectFile = Join-Path $Path 'default.project.json'
$projectText = Read-Text $projectFile
if ($projectText -notmatch '"name"\s*:\s*"MyGame"') {
    Fail 'default.project.json does not look like the template (no "name": "MyGame").'
}
$projectReplacement = '"name": "' + $Name + '"'
Write-Text $projectFile ($projectText -replace '"name"\s*:\s*"MyGame"', $projectReplacement)

$packageFile = Join-Path $Path 'package.json'
$packageText = Read-Text $packageFile
$packageReplacement = '"name": "' + $Name.ToLowerInvariant() + '"'
Write-Text $packageFile ($packageText -replace '"name"\s*:\s*"roblox-rojo-template"', $packageReplacement)

$configFile = Join-Path $Path 'src/ReplicatedStorage/Shared/Config.luau'
if (Test-Path -LiteralPath $configFile) {
    $configText = Read-Text $configFile
    if ($configText -match 'displayName = "My Game"') {
        $configReplacement = 'displayName = "' + $DisplayName + '"'
        Write-Text $configFile ($configText -replace 'displayName = "My Game"', $configReplacement)
    }
    else {
        Warn 'Config.luau had no default display name; leaving it untouched.'
    }
}
else {
    Fail "src/ReplicatedStorage/Shared/Config.luau is missing from the template."
}

# Verify before anything leaves this machine: valid JSON and no BOM.
try {
    $parsed = Read-Text $projectFile | ConvertFrom-Json
    if ($parsed.name -ne $Name) { throw 'the project name did not change' }
}
catch {
    Fail "The renamed project file is not valid JSON: $($_.Exception.Message)"
}
$bytes = [System.IO.File]::ReadAllBytes($projectFile)
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Fail 'default.project.json was written with a byte-order mark; Rojo cannot parse that.'
}
Info "rojo project : $Name"
Info "display name : $DisplayName"
Info 'verified: valid JSON, no BOM'

# --- dependencies ------------------------------------------------------------------------
if (-not $SkipInstall) {
    Step 'Installing test dependencies (a minute, once per project)'
    Push-Location $Path
    try {
        & npm ci --silent 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Warn 'npm ci failed; trying npm install instead.'
            & npm install --silent 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { Warn 'Dependency install failed. The game still builds; run npm install later for the tests.' }
        }
    }
    finally { Pop-Location }
}

# --- build -------------------------------------------------------------------------------
Step 'Building the place'
$buildScript = Join-Path $Path 'scripts/build.ps1'
if (-not (Test-Path -LiteralPath $buildScript)) { Fail 'scripts/build.ps1 is missing from the template.' }
Push-Location $Path
try {
    $global:LASTBUILDPATH = $null
    try { . $buildScript }
    catch {
        Fail ("The Rojo build failed: " + $_.Exception.Message + [Environment]::NewLine +
            "   Run it by hand for the full output: $buildScript")
    }
    if ($null -eq $global:LASTBUILDPATH -or -not (Test-Path -LiteralPath $global:LASTBUILDPATH)) {
        Fail 'The build reported success but produced no place file.'
    }
    $placeFile = $global:LASTBUILDPATH
    Info "place     $placeFile"
}
finally { Pop-Location }

# --- git and GitHub ----------------------------------------------------------------------
$pushed = $false
$owner = ''
$githubUrl = ''
if (-not $NoRepo) {
    Step 'Creating the git repository'
    Push-Location $Path
    try {
        & git init --quiet
        & git add -A
        & git -c user.email='new-game@local' -c user.name='new-game' commit --quiet -m 'Initial commit from the Roblox template'
        if ($LASTEXITCODE -ne 0) { Fail 'The initial git commit failed.' }
        # `gh repo create` repositories default to master; normalise to main before pushing.
        & git branch -M main
        Info 'first commit made on branch main'

        if ($hasGh) {
            $owner = (& gh api user --jq .login 2>$null)
            if (-not [string]::IsNullOrWhiteSpace($owner)) { $owner = $owner.Trim() }

            & gh repo view "$owner/$RepoName" 2>&1 | Out-Null
            $exists = ($LASTEXITCODE -eq 0)
            if (-not $exists) {
                $visibility = '--private'
                if ($Public) { $visibility = '--public' }
                Info "creating GitHub repository $RepoName ($($visibility.TrimStart('-')))"
                $createOutput = & gh repo create "$owner/$RepoName" $visibility --source . --remote origin --push 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Warn "gh repo create failed: $createOutput"
                    Warn 'The project is complete locally; push it once a repository exists.'
                }
                else { $pushed = $true }
            }
            else {
                Warn "GitHub repository $owner/$RepoName already exists; not creating a second one."
                if (-not $NoPush) {
                    & git remote add origin "https://github.com/$owner/$RepoName.git" 2>&1 | Out-Null
                    if ($LASTEXITCODE -ne 0) { & git remote set-url origin "https://github.com/$owner/$RepoName.git" }
                    $pushOutput = & git push -u origin main 2>&1
                    if ($LASTEXITCODE -eq 0) { $pushed = $true; Info 'pushed to the existing repository' }
                    else { Warn "push failed: $pushOutput" }
                }
            }
            if ($pushed) { $githubUrl = "https://github.com/$owner/$RepoName" }
        }
        else {
            Warn 'gh is not installed, so no GitHub repository was created.'
            Warn 'Create the repository on github.com, then from the project folder:'
            Warn ('  git remote add origin https://github.com/YOUR-ACCOUNT/' + $RepoName + '.git')
            Warn '  git push -u origin main'
        }
    }
    finally { Pop-Location }
}

# --- play --------------------------------------------------------------------------------
$opened = $false
if (-not $NoPlay) {
    Step 'Opening Roblox Studio'
    $studio = $null
    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Roblox\Versions'),
        'C:\Program Files\Roblox\Versions',
        'C:\Program Files (x86)\Roblox\Versions'
    )
    foreach ($root in $roots) {
        if ($null -ne $studio) { continue }
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $found = Get-ChildItem -Path $root -Filter 'RobloxStudioBeta.exe' -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($null -ne $found) { $studio = $found.FullName }
    }
    if ($null -eq $studio) {
        $command = Get-Command 'RobloxStudioBeta.exe' -ErrorAction SilentlyContinue
        if ($null -ne $command) { $studio = $command.Source }
    }
    if ($null -ne $studio) {
        Start-Process -FilePath $studio -ArgumentList ('"' + $placeFile + '"')
        $opened = $true
        Info 'Studio launched'
    }
    else {
        Warn 'Roblox Studio was not found automatically. Open this file:'
        Warn "  $placeFile"
    }
}

# --- summary -----------------------------------------------------------------------------
$stamp = 'dev'
Push-Location $Path
try {
    $sha = (& git rev-parse --short HEAD 2>$null)
    if (-not [string]::IsNullOrWhiteSpace($sha)) { $stamp = $sha.Trim() }
}
catch { }
finally { Pop-Location }

Write-Host ''
Write-Host "Ready: $Name" -ForegroundColor Green
Write-Host "  folder   $Path"
Write-Host "  build    $stamp  ($placeFile)"
if ($pushed) { Write-Host "  github   $githubUrl" }
elseif ($NoRepo) { Write-Host '  github   skipped (-NoRepo)' }
else { Write-Host '  github   not pushed; see the messages above' }
Write-Host ''
Write-Host 'Everyday commands, from inside the project folder:'
Write-Host '  .\scripts\play.ps1              pull, build, open Studio'
Write-Host '  .\scripts\play.ps1 -SkipPull    build and open without pulling'
Write-Host '  .\scripts\test.ps1              run the project checks'
if (-not $opened) { Write-Host ''; Write-Host "Open the place yourself: $placeFile" }
