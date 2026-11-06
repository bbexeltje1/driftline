# This script is dot-sourced by play.ps1 and by the standalone new-game.ps1 launcher. It must
# therefore never call `exit` (that would end the caller's session) -- failures propagate as
# exceptions instead.

# Build the Roblox place from source. Never publishes anything.
$repositoryRoot = $PSScriptRoot | Split-Path -Parent
$projectFile = Join-Path $repositoryRoot 'default.project.json'
$outputDirectory = Join-Path $repositoryRoot 'build'
$outputFile = Join-Path $outputDirectory 'game.rbxlx'

$rojo = Get-Command 'rojo' -ErrorAction SilentlyContinue
if ($null -eq $rojo) {
    throw 'Rojo CLI was not found. Install it and add rojo.exe to PATH: https://rojo.space'
}
if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
    throw "Rojo project file not found: $projectFile"
}

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
Set-Content -LiteralPath $tagFile -Value "return { tag = `"$stamp`" }" -NoNewline
Write-Host "Stamped build $stamp"

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
& $rojo.Source build $projectFile --output $outputFile
if ($LASTEXITCODE -ne 0) {
    throw "Rojo build failed with exit code $LASTEXITCODE."
}
if (-not (Test-Path -LiteralPath $outputFile -PathType Leaf)) {
    throw "Rojo reported success but did not create $outputFile"
}

Write-Host "Build succeeded: $outputFile" -ForegroundColor Green
# Record success for callers; an `exit` code does not propagate out of a nested script.
$global:LASTBUILDPATH = $outputFile
$global:LASTBUILDSTAMP = $stamp
