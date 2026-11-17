# This script is dot-sourced by play.ps1 and by the standalone new-game.ps1 launcher. It must
# therefore never call `exit` (that would end the caller's session) -- failures propagate as
# exceptions instead.

# Build the Roblox place from source. Never publishes anything.
$repositoryRoot = $PSScriptRoot | Split-Path -Parent
$projectFile = Join-Path $repositoryRoot 'default.project.json'
$outputDirectory = Join-Path $repositoryRoot 'build'
$outputFile = Join-Path $outputDirectory 'game.rbxlx'

# Pinned to the version CI uses (.github/workflows/checks.yml) so local and CI builds match.
$rojoVersion = '7.7.1'

function Resolve-Rojo {
    $command = Get-Command 'rojo' -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }

    # No Rojo on PATH: fetch the pinned release once into the git-ignored .tools folder.
    $toolDir = Join-Path $repositoryRoot ('.tools\rojo-' + $rojoVersion)
    $existing = Get-ChildItem -Path $toolDir -Filter 'rojo.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $existing) { return $existing.FullName }

    $url = 'https://github.com/rojo-rbx/rojo/releases/download/v' + $rojoVersion + '/rojo-' + $rojoVersion + '-windows-x86_64.zip'
    Write-Host ('Rojo is not installed. Downloading Rojo ' + $rojoVersion + ' once into .tools ...')
    New-Item -ItemType Directory -Path $toolDir -Force | Out-Null
    $zip = Join-Path $toolDir 'rojo.zip'
    try {
        # Windows PowerShell 5.1 defaults to older TLS, which GitHub refuses.
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        Expand-Archive -LiteralPath $zip -DestinationPath $toolDir -Force
    }
    catch {
        throw ('Could not download Rojo from ' + $url + ' (' + $_.Exception.Message + '). ' +
            'Install Rojo ' + $rojoVersion + ' from https://rojo.space or add rojo.exe to PATH, then run .\scripts\play.ps1 again.')
    }
    finally {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    }
    $downloaded = Get-ChildItem -Path $toolDir -Filter 'rojo.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $downloaded) { throw ('Rojo archive did not contain rojo.exe (' + $url + ').') }
    return $downloaded.FullName
}

if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
    throw "Rojo project file not found: $projectFile"
}
$rojoExe = Resolve-Rojo

# Stamp the build. The file is generated and git-ignored; writing it here means the place
# always carries its own version, so "which build am I playing" is answerable in-game.
$stamp = 'dev'
try {
    $sha = (& git rev-parse --short HEAD 2>$null)
    if (-not [string]::IsNullOrWhiteSpace($sha)) { $stamp = $sha.Trim() }
}
catch {
    Write-Host 'Git unavailable; stamping the build as dev.' -ForegroundColor Yellow
}
$tagFile = Join-Path $repositoryRoot 'src/ReplicatedStorage/Shared/BuildTag.luau'
Set-Content -LiteralPath $tagFile -Value "return { tag = `"$stamp`" }" -NoNewline -Encoding ASCII
Write-Host "Stamped build $stamp"

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
if (Test-Path -LiteralPath $outputFile) { Remove-Item -LiteralPath $outputFile -Force }
& $rojoExe build $projectFile --output $outputFile
if ($LASTEXITCODE -ne 0) {
    throw "Rojo build failed with exit code $LASTEXITCODE."
}
if (-not (Test-Path -LiteralPath $outputFile -PathType Leaf)) {
    throw "Rojo reported success but did not create $outputFile"
}
Write-Host "Build succeeded: $outputFile" -ForegroundColor Green

# Verify the finished place really contains the M1 systems before Studio opens it.
$node = Get-Command 'node' -ErrorAction SilentlyContinue
if ($null -ne $node) {
    & $node.Source (Join-Path $repositoryRoot 'tests/place-check.mjs') $outputFile
    if ($LASTEXITCODE -ne 0) { throw 'Place check failed: the built place is missing required M1 systems.' }
}
else {
    Write-Host 'Node.js not found, so the place check was skipped (install Node 22 to enable it).' -ForegroundColor Yellow
}

# Record success for callers; an `exit` code does not propagate out of a nested script.
$global:LASTBUILDPATH = $outputFile
$global:LASTBUILDSTAMP = $stamp
