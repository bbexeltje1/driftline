param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Destination = '',
    [string]$DisplayName = '',
    # Do the whole job in one call: create the GitHub repository, push, then build and open
    # Studio. Leaves the template folder without changing it, whatever directory you are in.
    [switch]$CreateRepo,
    [switch]$Private,
    [switch]$Play
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Printed first, deliberately: if this line does not appear, the file on disk is not the
# version that supports -CreateRepo/-Private/-Play, and the fix is to update the checkout.
$templateVersion = '1.2'
Write-Host "new-project.ps1 $templateVersion" -ForegroundColor DarkGray

# Copies this template into a brand-new project folder, ready for a fresh git repository.
# Nothing here touches the template itself.
$templateRoot = $PSScriptRoot | Split-Path -Parent

# Default destination: a sibling of the REPOSITORY this template lives in, not a sibling of the
# template folder. `template-rojo` sits inside the repository, so going up one level would put
# new projects inside the repository (which is what happened the first time).
$repositoryRoot = $templateRoot
if ($null -ne (Get-Command 'git' -ErrorAction SilentlyContinue)) {
    $topLevel = (& git -C $templateRoot rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($topLevel)) {
        $repositoryRoot = $topLevel.Trim()
    }
}
if ([string]::IsNullOrWhiteSpace($Destination)) {
    $Destination = Join-Path (Split-Path $repositoryRoot -Parent) $Name
}
if (Test-Path -LiteralPath $Destination) {
    $existing = @(Get-ChildItem -LiteralPath $Destination -Force)
    if ($existing.Count -gt 0) {
        throw "Destination already exists and is not empty: $Destination" + [Environment]::NewLine +
            'Delete it first, or pass -Destination with another path.'
    }
}
$fullDestination = [System.IO.Path]::GetFullPath($Destination)
$fullRepository = [System.IO.Path]::GetFullPath($repositoryRoot)
if ($fullDestination -eq $fullRepository -or
    $fullDestination.StartsWith($fullRepository + [System.IO.Path]::DirectorySeparatorChar)) {
    throw ("The new project cannot be created inside the repository at $fullRepository." + [Environment]::NewLine +
        'Pass -Destination with a path outside it, for example ..\' + $Name)
}
if ($Name -notmatch '^[a-zA-Z0-9._-]+$') {
    throw "Use letters, digits, dots, dashes or underscores for the name: '$Name'"
}
if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = $Name }

Write-Host "Creating $Name in $Destination ..."
Write-Host "  (sibling of the repository at $repositoryRoot)" -ForegroundColor DarkGray
New-Item -ItemType Directory -Path $Destination -Force | Out-Null

# Copy the template, then drop generated and machine-local folders. node_modules is copied
# last-wins earlier in development; a fresh project installs its own with `npm ci`.
$skipDirectories = @('node_modules', 'build', '.git')
Copy-Item -Path (Join-Path $templateRoot '*') -Destination $Destination -Recurse -Force
Get-ChildItem -Path $Destination -Directory -Recurse -Force |
    Where-Object { $skipDirectories -contains $_.Name } |
    Sort-Object { $_.FullName.Length } -Descending |
    ForEach-Object { if (Test-Path -LiteralPath $_.FullName) { Remove-Item -LiteralPath $_.FullName -Recurse -Force } }

# Write UTF-8 WITHOUT a byte-order mark. On Windows PowerShell 5.1 `-Encoding utf8` emits a
# BOM, and Rojo's parser rejects it: "Failed to parse JSONC" on a perfectly valid file.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Write-TextFile([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}
function Read-TextFile([string]$Path) {
    return [System.IO.File]::ReadAllText($Path)
}

# Rename the project in the places Rojo and the game read it. Written back as text, not via
# ConvertTo-Json, so the file keeps its shape and the template's own formatting.
$projectFile = Join-Path $Destination 'default.project.json'
$projectText = Read-TextFile $projectFile
if ($projectText -notmatch '"name"\s*:\s*"MyGame"') {
    throw "default.project.json does not contain the expected template name 'MyGame'."
}
Write-TextFile $projectFile ($projectText -replace '"name"\s*:\s*"MyGame"', "`"name`": `"$Name`"")

$packageFile = Join-Path $Destination 'package.json'
$packageText = Read-TextFile $packageFile
Write-TextFile $packageFile ($packageText -replace '"name"\s*:\s*"roblox-rojo-template"', "`"name`": `"$($Name.ToLowerInvariant())`"")

$configFile = Join-Path $Destination 'src/ReplicatedStorage/Shared/Config.luau'
$configText = Read-TextFile $configFile
if ($configText -notmatch 'displayName = "My Game"') {
    throw "Config.luau does not contain the expected display name 'My Game'."
}
Write-TextFile $configFile ($configText -replace 'displayName = "My Game"', "displayName = `"$DisplayName`"")

# Fail loudly here rather than inside Rojo later: the file must be valid JSON and BOM-free.
try {
    $parsed = Read-TextFile $projectFile | ConvertFrom-Json
    if ($parsed.name -ne $Name) { throw "rename did not take effect in default.project.json" }
}
catch {
    throw "The renamed project file is not valid JSON: $($_.Exception.Message)"
}
$bytes = [System.IO.File]::ReadAllBytes($projectFile)
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    throw 'default.project.json was written with a byte-order mark; Rojo cannot parse that.'
}
Write-Host 'Project files renamed and verified (UTF-8, no BOM).'

Push-Location $Destination
try {
    & git init -q
    & git add -A
    & git -c user.email='template@local' -c user.name='template' commit -q -m 'Initial commit'

    $uploaded = $false
    if ($CreateRepo) {
        $gh = Get-Command 'gh' -ErrorAction SilentlyContinue
        if ($null -eq $gh) {
            Write-Host 'GitHub CLI (gh) was not found, so no repository was created.' -ForegroundColor Yellow
            Write-Host 'Install it from https://cli.github.com, or create the repo on github.com and push.'
        }
        else {
            $visibility = if ($Private) { '--private' } else { '--public' }
            Write-Host "Creating the GitHub repository $Name ..."
            & gh repo create $Name $visibility --source . --push
            if ($LASTEXITCODE -ne 0) {
                Write-Host 'gh repo create failed. The project is complete locally; push it when ready.' -ForegroundColor Yellow
            }
            else {
                $uploaded = $true
            }
        }
    }

    Write-Host ''
    Write-Host "Created $Destination" -ForegroundColor Green
    Write-Host 'Next:'
    Write-Host "  cd `"$Destination`""
    if (-not $uploaded) {
        Write-Host '  # create the repository, then push (or re-run with -CreateRepo -Private):'
        Write-Host ('  gh repo create ' + $Name + ' --private --source . --push')
    }
    if ($Play) {
        Write-Host ''
        Write-Host 'Building and opening Studio ...'
        & (Join-Path $Destination 'scripts/play.ps1') -SkipPull
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'Play failed; fix the message above and run .\scripts\play.ps1 inside the new folder.' -ForegroundColor Yellow
        }
    }
    else {
        Write-Host '  .\scripts\play.ps1 -SkipPull'
    }
}
finally {
    Pop-Location
}
