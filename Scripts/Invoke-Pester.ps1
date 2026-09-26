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

# A test file that cannot be parsed, or that fails during discovery, produces a
# failed *container* rather than a failed test. Checking FailedCount alone reports
# a broken suite as green.
$FailureCount = $result.FailedCount + $result.FailedContainersCount + $result.FailedBlocksCount

if ($FailureCount -gt 0) {
    Write-Host "`nTest run failed: $($result.FailedCount) test(s), $($result.FailedContainersCount) container(s) failed to run, $($result.FailedBlocksCount) block(s)." -ForegroundColor Red

    foreach ($container in $result.FailedContainers) {
        Write-Host "  $($container.Item): $($container.ErrorRecord.Exception.Message)" -ForegroundColor Red
    }

    # Non-zero so a calling script or CI job fails too.
    exit 1
}

Write-Host "`nAll $($result.TotalCount) tests passed successfully!" -ForegroundColor Green
