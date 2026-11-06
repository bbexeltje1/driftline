param(
    # The repository to fill. Defaults to the current directory, so the usual flow is:
    #   cd C:\Users\you\my-game
    #   .\fill-repository.ps1
    [string]$RepositoryPath = '',
    # In-game title. Defaults to the repository name.
    [string]$DisplayName = '',
    # Copy the template from a folder on disk instead of downloading it. When this script is
    # run from inside the template repository it finds template-rojo automatically.
    [string]$TemplatePath = '',
    [switch]$Force,
    [switch]$SkipInstall,
    [switch]$NoBuild,
    [switch]$NoPlay,
    [switch]$Commit,
    [switch]$Push,
    [string]$CommitMessage = 'Add the Roblox game starter template'
)
$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 turns *any* native-program stderr output into a fatal error
# (NativeCommandError), and git writes hints and progress there even on success.
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}
Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------------------
# fill-repository.ps1 1.0
# You have already made an empty repository (on GitHub, or with `git init`). This fills it
# with the template -- the same one-command play loop, tests and CI as a fresh project --
# and can commit and push the result. Works from any directory.
# ---------------------------------------------------------------------------------------
$Version = '1.0'
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

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Write-Text([string]$File, [string]$Text) { [System.IO.File]::WriteAllText($File, $Text, $utf8NoBom) }
function Read-Text([string]$File) { return [System.IO.File]::ReadAllText($File) }

Write-Host "fill-repository.ps1 $Version" -ForegroundColor DarkGray

# --- where we are ------------------------------------------------------------------------
Step 'Working out what to fill'
if ([string]::IsNullOrWhiteSpace($RepositoryPath)) { $RepositoryPath = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $RepositoryPath)) { Fail "No such folder: $RepositoryPath" }
$RepositoryPath = [System.IO.Path]::GetFullPath($RepositoryPath)
if (-not (Test-Path -LiteralPath $RepositoryPath -PathType Container)) { Fail "$RepositoryPath is not a folder." }

$isGitRepository = Test-Path -LiteralPath (Join-Path $RepositoryPath '.git')
$repoName = Split-Path $RepositoryPath -Leaf
$remoteUrl = ''
if ($isGitRepository) {
    $remoteUrl = (& git -C $RepositoryPath remote get-url origin 2>$null)
    if ($LASTEXITCODE -ne 0) { $remoteUrl = '' }
    if (-not [string]::IsNullOrWhiteSpace($remoteUrl)) {
        $remoteUrl = $remoteUrl.Trim()
        $candidate = ($remoteUrl -split '/')[-1]
        $candidate = $candidate -replace '\.git$', ''
        if (-not [string]::IsNullOrWhiteSpace($candidate)) { $repoName = $candidate }
    }
}
if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = $repoName }
Info "repository  $RepositoryPath"
Info "git repo    $isGitRepository"
if (-not [string]::IsNullOrWhiteSpace($remoteUrl)) { Info "remote      $remoteUrl" }
Info "project     $repoName"

if ($repoName -notmatch '^[a-zA-Z0-9._-]+$') {
    Fail "The repository name '$repoName' has characters the Rojo project cannot use." + [Environment]::NewLine +
        '   Pass -DisplayName and rename the folder, or fill a folder with a simpler name.'
}
if (-not $isGitRepository) {
    Warn 'This folder is not a git repository. Files will be added, but there is nothing to commit yet.'
    if ($Push) { Fail 'Cannot push: this folder has no .git. Run `git init` and add a remote first, or drop -Push.' }
}

# --- refuse to trample work ---------------------------------------------------------------
$templateFiles = @('default.project.json', 'package.json', 'src', 'scripts', 'tests')
$existing = @()
foreach ($item in $templateFiles) {
    if (Test-Path -LiteralPath (Join-Path $RepositoryPath $item)) { $existing += $item }
}
if ($existing.Count -gt 0 -and -not $Force) {
    Fail ("This repository already contains template files: " + ($existing -join ', ') + [Environment]::NewLine +
        '   Add -Force to overwrite them. Anything else in the folder is left alone.')
}
if ($existing.Count -gt 0) { Warn ("Overwriting: " + ($existing -join ', ') + ' (-Force)') }

# --- find the template -------------------------------------------------------------------
Step 'Locating the template'
$templateSource = ''
$download = $false
if (-not [string]::IsNullOrWhiteSpace($TemplatePath)) {
    if (-not (Test-Path -LiteralPath $TemplatePath)) { Fail "TemplatePath does not exist: $TemplatePath" }
    $templateSource = [System.IO.Path]::GetFullPath($TemplatePath)
}
elseif ((Test-Path -LiteralPath ([System.IO.Path]::Combine($PSScriptRoot, 'src'))) -and
        (Test-Path -LiteralPath ([System.IO.Path]::Combine($PSScriptRoot, 'scripts')))) {
    # This script is inside template-rojo (the normal case when it is used from the repo).
    $templateSource = $PSScriptRoot
}
else {
    $download = $true
}

$temp = ''
if ($download) {
    Info "downloading $TemplateRepo ($TemplateBranch)"
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ('fill-repo-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $clone = Join-Path $temp 'repo'
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    $cloneOutput = & git -c core.askPass= clone --quiet --depth 1 --branch $TemplateBranch "https://github.com/$TemplateRepo.git" $clone 2>&1
    if ($LASTEXITCODE -ne 0) {
        $hint = ''
        if (($cloneOutput -join ' ') -match 'could not read Username|Authentication failed|terminal prompts disabled') {
            $hint = [Environment]::NewLine +
                '   The template repository is private, so this machine must be signed in to GitHub:' + [Environment]::NewLine +
                '     gh auth login' + [Environment]::NewLine +
                '   Or point at a copy you already have:' + [Environment]::NewLine +
                '     -TemplatePath C:\Users\exelt\Newgame\template-rojo'
        }
        Fail ("Could not download the template from https://github.com/$TemplateRepo" + [Environment]::NewLine +
            "   $cloneOutput" + $hint)
    }
    $templateSource = Join-Path $clone $TemplateFolder
    if (-not (Test-Path -LiteralPath $templateSource)) {
        Fail "The template folder '$TemplateFolder' is not in $TemplateRepo ($TemplateBranch)."
    }
}

try {
    # --- copy -----------------------------------------------------------------------------
    Step 'Copying the template'
    if (-not (Test-Path -LiteralPath $templateSource -PathType Container)) { Fail "$templateSource is not a folder." }
    Copy-Item -Path (Join-Path $templateSource '*') -Destination $RepositoryPath -Recurse -Force
    # Wildcard copies are inconsistent about dot-files on older PowerShell builds.
    foreach ($dotItem in @('.gitignore', '.gitattributes', '.github')) {
        $from = Join-Path $templateSource $dotItem
        if (Test-Path -LiteralPath $from) {
            Copy-Item -Path $from -Destination (Join-Path $RepositoryPath $dotItem) -Recurse -Force
        }
    }
    foreach ($junk in @('node_modules', 'build')) {
        $junkPath = Join-Path $RepositoryPath $junk
        if (Test-Path -LiteralPath $junkPath) { Remove-Item -LiteralPath $junkPath -Recurse -Force }
    }

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
        if (-not (Test-Path -LiteralPath (Join-Path $RepositoryPath $requiredFile))) { $missingFiles += $requiredFile }
    }
    if ($missingFiles.Count -gt 0) {
        Fail ("The template came down incomplete. Missing: " + ($missingFiles -join ', '))
    }
    Info 'copied and checked'

    # --- rename ---------------------------------------------------------------------------
    Step 'Naming the project'
    $projectFile = Join-Path $RepositoryPath 'default.project.json'
    $projectText = Read-Text $projectFile
    if ($projectText -notmatch '"name"\s*:\s*"MyGame"') {
        Fail 'default.project.json does not look like the template (no "name": "MyGame").'
    }
    $projectReplacement = '"name": "' + $repoName + '"'
    Write-Text $projectFile ($projectText -replace '"name"\s*:\s*"MyGame"', $projectReplacement)

    $packageFile = Join-Path $RepositoryPath 'package.json'
    $packageText = Read-Text $packageFile
    $packageReplacement = '"name": "' + $repoName.ToLowerInvariant() + '"'
    Write-Text $packageFile ($packageText -replace '"name"\s*:\s*"roblox-rojo-template"', $packageReplacement)

    $configFile = Join-Path $RepositoryPath 'src/ReplicatedStorage/Shared/Config.luau'
    $configText = Read-Text $configFile
    if ($configText -match 'displayName = "My Game"') {
        $configReplacement = 'displayName = "' + $DisplayName + '"'
        Write-Text $configFile ($configText -replace 'displayName = "My Game"', $configReplacement)
    }

    # Verify before anything is committed: valid JSON, no byte-order mark.
    try {
        $parsed = Read-Text $projectFile | ConvertFrom-Json
        if ($parsed.name -ne $repoName) { throw 'the project name did not change' }
    }
    catch {
        Fail "The renamed project file is not valid JSON: $($_.Exception.Message)"
    }
    $bytes = [System.IO.File]::ReadAllBytes($projectFile)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Fail 'default.project.json was written with a byte-order mark; Rojo cannot parse that.'
    }
    Info "rojo project : $repoName"
    Info "display name : $DisplayName"
    Info 'verified: valid JSON, no BOM'

    # --- dependencies ---------------------------------------------------------------------
    if (-not $SkipInstall) {
        Step 'Installing test dependencies'
        Push-Location $RepositoryPath
        try {
            & npm ci --silent 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Warn 'npm ci failed; trying npm install instead.'
                & npm install --silent 2>&1 | Out-Null
            }
        }
        finally { Pop-Location }
    }

    # --- build ----------------------------------------------------------------------------
    $placeFile = ''
    if (-not $NoBuild) {
        Step 'Building the place'
        $buildScript = Join-Path $RepositoryPath 'scripts/build.ps1'
        if (-not (Test-Path -LiteralPath $buildScript)) { Fail 'scripts/build.ps1 is missing.' }
        Push-Location $RepositoryPath
        try {
            $global:LASTBUILDPATH = $null
            try { . $buildScript }
            catch { Fail ("The Rojo build failed: " + $_.Exception.Message) }
            if ($null -eq $global:LASTBUILDPATH -or -not (Test-Path -LiteralPath $global:LASTBUILDPATH)) {
                Fail 'The build reported success but produced no place file.'
            }
            $placeFile = $global:LASTBUILDPATH
            Info "place     $placeFile"
        }
        finally { Pop-Location }
    }

    # --- commit and push ------------------------------------------------------------------
    $pushed = $false
    if ($Commit -or $Push) {
        Step 'Committing'
        Push-Location $RepositoryPath
        try {
            & git add -A
            & git -c user.email='template@local' -c user.name='template' commit --quiet -m $CommitMessage
            if ($LASTEXITCODE -ne 0) {
                Warn 'Nothing to commit, or the commit failed. The files are in place regardless.'
            }
            else { Info 'committed' }

            if ($Push) {
                $branch = (& git rev-parse --abbrev-ref HEAD).Trim()
                if ([string]::IsNullOrWhiteSpace($branch) -or $branch -eq 'HEAD') { $branch = 'main' }
                Info "pushing $branch"
                $pushOutput = & git push -u origin $branch 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Warn "push failed: $pushOutput"
                    Warn 'The commit exists locally; fix the remote or credentials and push again.'
                }
                else { $pushed = $true; Info 'pushed' }
            }
        }
        finally { Pop-Location }
    }

    # --- play -----------------------------------------------------------------------------
    if (-not $NoPlay -and -not [string]::IsNullOrWhiteSpace($placeFile)) {
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
            Info 'Studio launched'
        }
        else {
            Warn 'Roblox Studio was not found automatically. Open this file:'
            Warn "  $placeFile"
        }
    }

    Write-Host ''
    Write-Host "Filled: $RepositoryPath" -ForegroundColor Green
    Write-Host "  project  $repoName  ($DisplayName)"
    if (-not [string]::IsNullOrWhiteSpace($placeFile)) { Write-Host "  build    $placeFile" }
    if ($pushed) { Write-Host "  github   $remoteUrl" }
    Write-Host ''
    Write-Host 'From inside that folder:'
    Write-Host '  .\scripts\play.ps1              pull, build, open Studio'
    Write-Host '  .\scripts\play.ps1 -SkipPull    build and open without pulling'
    Write-Host '  .\scripts\test.ps1              run the project checks'
    if (-not $Commit -and -not $Push) {
        Write-Host ''
        Write-Host 'Nothing was committed. To commit and push yourself:'
        Write-Host '  git add -A'
        Write-Host ('  git commit -m "' + $CommitMessage + '"')
        Write-Host '  git push -u origin HEAD'
    }
}
finally {
    if (-not [string]::IsNullOrWhiteSpace($temp) -and (Test-Path -LiteralPath $temp)) {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
