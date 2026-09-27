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

# Every path out of this script must set a non-zero exit code, not just write to
# the error stream. A caller that checks $LASTEXITCODE, or a CI job, sees only the
# exit code: Write-Error alone leaves a skipped or broken run indistinguishable
# from a pass. See AGENTS.md 1.8 on not gating on a check that can be skipped.
if (-not $pester) {
    Write-Error "Pester v5+ is required. Run: Install-Module Pester -Force -SkipPublisherCheck -Scope CurrentUser"
    Write-Error "No tests were run, so this result is unverified."
    exit 1
}

$ModuleRoot = Split-Path -Parent $PSScriptRoot
$TestsPath  = Join-Path -Path $ModuleRoot -ChildPath "Tests"

if (-not (Test-Path -Path $TestsPath)) {
    Write-Error "Tests directory not found at '$TestsPath'."
    Write-Error "No tests were run, so this result is unverified."
    exit 1
}

Write-Host "Running PSToolkit Test Suite (Pester v$($pester.Version))..." -ForegroundColor Cyan

# Pester 5+ Configuration Object
$config = [PesterConfiguration]::Default
$config.Run.Path = $TestsPath
$config.Output.Verbosity = 'Detailed'

# PassThru defaults to $false, in which case Invoke-Pester returns nothing at all
# in Pester 6. Every count below is then $null, the total reads as 0, and a
# failing suite is reported as a pass. This line is what makes the gate a gate.
$config.Run.PassThru = $true

$result = Invoke-Pester -Configuration $config

if ($null -eq $result) {
    # Defence in depth. If the run produces no result object there is no evidence
    # that anything passed, and silence must not be reported as success.
    Write-Host "`nTest run produced no result object, so nothing was verified." -ForegroundColor Red
    exit 1
}

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
