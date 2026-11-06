param(
    [switch]$SkipPull,
    [switch]$NoOpen
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# One command: pull, build, open in Studio. Test scripts only ever run explicitly, so a
# broken test can never stand between you and pressing Play.
$repositoryRoot = $PSScriptRoot | Split-Path -Parent
$outputFile = Join-Path (Join-Path $repositoryRoot 'build') 'game.rbxlx'

# Files the build rewrites. Local edits to these are never worth keeping, and a tracked
# generated file once blocked every pull -- clear them before pulling.
$generatedFiles = @('src/ReplicatedStorage/Shared/BuildTag.luau')

function Clear-GeneratedEdits {
    if ($null -eq (Get-Command 'git' -ErrorAction SilentlyContinue)) { return $false }
    $dirty = @(& git status --porcelain -- $generatedFiles 2>$null)
    if ($LASTEXITCODE -ne 0 -or $dirty.Count -eq 0) { return $false }
    & git checkout -- $generatedFiles 2>$null
    if ($LASTEXITCODE -ne 0) {
        & git reset -q -- $generatedFiles 2>$null
        & git checkout -- $generatedFiles 2>$null
    }
    Write-Host 'Discarded the generated build stamp (it is rebuilt automatically).'
    return $true
}

try {
    Push-Location $repositoryRoot
    try {
        if (-not $SkipPull) {
            # A freshly copied folder may not be a git repository yet. Pulling there fails with
            # a message about local changes, which is both wrong and alarming, so skip it.
            if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot '.git'))) {
                Write-Host 'Not a git repository yet, so there is nothing to pull. Building the local files.'
                $SkipPull = $true
            }
        }
        if (-not $SkipPull) {
            $branch = (& git rev-parse --abbrev-ref HEAD 2>$null)
            if ($null -ne $branch) { $branch = $branch.Trim() }
            if ([string]::IsNullOrWhiteSpace($branch) -or $branch -eq 'HEAD') {
                Write-Host 'No branch checked out yet, so there is nothing to pull.'
                $SkipPull = $true
            }
        }
        if (-not $SkipPull) {
            [void](Clear-GeneratedEdits)
            Write-Host "Pulling origin/$branch ..."
            & git pull --ff-only origin $branch
            if ($LASTEXITCODE -ne 0 -and (Clear-GeneratedEdits)) {
                & git pull --ff-only origin $branch
            }
            if ($LASTEXITCODE -ne 0) {
                $blocking = @(& git status --short) -join [Environment]::NewLine
                throw ("git pull is blocked by local changes:" + [Environment]::NewLine + $blocking +
                    [Environment]::NewLine + "Keep them with 'git stash', then run .\scripts\play.ps1 again.")
            }
        }

        $stamp = 'dev'
        try { $sha = (& git rev-parse --short HEAD 2>$null); if (-not [string]::IsNullOrWhiteSpace($sha)) { $stamp = $sha.Trim() } } catch { }
        Write-Host "Building $stamp ..."
        $global:LASTBUILDPATH = $null
        # A build failure must explain itself: Rojo reports JSON problems in Output, and the
        # usual cause on Windows is a byte-order mark written by an editor or a script.
        try {
            . (Join-Path $PSScriptRoot 'build.ps1')
        }
        catch {
            Write-Host ''
            Write-Host ("Build failed: " + $_.Exception.Message) -ForegroundColor Red
            $projectFile = Join-Path $repositoryRoot 'default.project.json'
            if (Test-Path -LiteralPath $projectFile) {
                $bytes = [System.IO.File]::ReadAllBytes($projectFile)
                if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
                    Write-Host 'default.project.json starts with a byte-order mark, which Rojo cannot parse.' -ForegroundColor Yellow
                    Write-Host 'Re-save it as UTF-8 without BOM (or re-create the project with scripts/new-project.ps1).'
                }
                else {
                    Write-Host "Check that $projectFile is valid JSON (no trailing commas, no comments)."
                }
            }
            throw
        }
        if ($null -eq $global:LASTBUILDPATH) {
            throw 'build.ps1 finished without reporting a build; nothing was opened.'
        }
        if (-not (Test-Path -LiteralPath $outputFile -PathType Leaf)) {
            throw "Build reported success but $outputFile is missing."
        }

        $built = Get-Item -LiteralPath $outputFile
        Write-Host ''
        Write-Host ("Build {0} ready ({1:N0} KB, saved {2:HH:mm:ss})." -f $stamp, ($built.Length / 1KB), $built.LastWriteTime) -ForegroundColor Green
        Write-Host 'Press Play in Studio. Studio progress is temporary by design: nothing to publish, no API settings.'

        if (-not $NoOpen) {
            $studio = $null
            foreach ($root in @((Join-Path $env:LOCALAPPDATA 'Roblox\Versions'), 'C:\Program Files\Roblox\Versions', 'C:\Program Files (x86)\Roblox\Versions')) {
                if ($null -ne $studio -or -not (Test-Path -LiteralPath $root)) { continue }
                $found = Get-ChildItem -Path $root -Filter 'RobloxStudioBeta.exe' -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($null -ne $found) { $studio = $found.FullName }
            }
            if ($null -eq $studio) {
                $command = Get-Command 'RobloxStudioBeta.exe' -ErrorAction SilentlyContinue
                if ($null -ne $command) { $studio = $command.Source }
            }
            if ($null -ne $studio) {
                Write-Host "Opening $studio ..."
                Start-Process -FilePath $studio -ArgumentList "`"$outputFile`""
            }
            else {
                Write-Host 'Studio was not found automatically. Open this file:' -ForegroundColor Yellow
                Write-Host "  $outputFile"
            }
        }
    }
    finally {
        Pop-Location
    }
}
catch {
    [Console]::Error.WriteLine("Playtest failed: {0}" -f $_.Exception.Message)
    exit 1
}
