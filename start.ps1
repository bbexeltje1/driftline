param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$DisplayName = '',
    [string]$Destination = '',
    # Convenience front door: forwards everything to scripts/new-project.ps1.
    [switch]$CreateRepo,
    [switch]$Private,
    [switch]$Play
)
$ErrorActionPreference = 'Stop'

# Works from any directory, because it resolves the script by its own location.
$script = Join-Path $PSScriptRoot 'scripts/new-project.ps1'
if (-not (Test-Path -LiteralPath $script)) {
    throw "scripts/new-project.ps1 is missing next to this file. Update your checkout."
}
$arguments = @{ Name = $Name; CreateRepo = $CreateRepo; Private = $Private; Play = $Play }
if (-not [string]::IsNullOrWhiteSpace($DisplayName)) { $arguments.DisplayName = $DisplayName }
if (-not [string]::IsNullOrWhiteSpace($Destination)) { $arguments.Destination = $Destination }
& $script @arguments
