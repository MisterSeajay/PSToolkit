<#
.SYNOPSIS
    Runs the Pester test suite for PSToolkit.
.DESCRIPTION
    Executes unit, structure, and quality tests located in the Tests/ folder using Pester 5+.
.EXAMPLE
    .\Scripts\Invoke-Pester.ps1
#>
[CmdletBinding()]
param()

# Ensure Pester v5+ is loaded
$pester = Import-Module Pester -MinimumVersion 5.0.0 -PassThru -ErrorAction SilentlyContinue

if (-not $pester) {
    Write-Error "Pester v5+ is required. Run: Install-Module Pester -Force -SkipPublisherCheck -Scope CurrentUser"
    return
}

$ModuleRoot = Split-Path -Parent $PSScriptRoot
$TestsPath  = Join-Path -Path $ModuleRoot -ChildPath "Tests"

if (-not (Test-Path -Path $TestsPath)) {
    Write-Error "Tests directory not found at '$TestsPath'."
    return
}

Write-Host "Running PSToolkit Test Suite (Pester v$($pester.Version))..." -ForegroundColor Cyan

# Pester 5+ Configuration Object
$config = [PesterConfiguration]::Default
$config.Run.Path = $TestsPath
$config.Output.Verbosity = 'Detailed'

$result = Invoke-Pester -Configuration $config

if ($result.FailedCount -gt 0) {
    Write-Host "`nTest run failed: $($result.FailedCount) test(s) failed." -ForegroundColor Red
} else {
    Write-Host "`nAll $($result.TotalCount) tests passed successfully!" -ForegroundColor Green
}