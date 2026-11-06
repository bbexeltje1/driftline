$ErrorActionPreference = 'Stop'
$repositoryRoot = $PSScriptRoot | Split-Path -Parent
Push-Location $repositoryRoot
try {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'node_modules'))) {
        & npm ci
        if ($LASTEXITCODE -ne 0) { throw 'npm ci failed' }
    }
    & npm test
    if ($LASTEXITCODE -ne 0) { throw "Tests failed with exit code $LASTEXITCODE" }
    Write-Host 'All checks passed.' -ForegroundColor Green
}
finally {
    Pop-Location
}
