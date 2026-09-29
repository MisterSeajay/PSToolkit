<#
.SYNOPSIS
    Builds the PSToolkit module and copies it to a specified output path.
.DESCRIPTION
    1. Runs the Pester suite and refuses to build if it is not green.
    2. Parses Public/ using the PowerShell AST to discover exported functions and
       Set-Alias definitions.
    3. Removes any existing content at the destination, then copies the module
       files, Public/, Private/, Scripts/, the README and the licence.
    4. Writes the discovered export lists into the *copied* manifest, so the
       manifest checked into the repository is never rewritten by a build.

    The source PSToolkit.psd1 is treated as hand-owned. Its export lists are
    checked against what Public/ actually contains by Tests/PSToolkit.tests.ps1,
    which fails if a function was added to Public/ and forgotten in the manifest.
    Deriving them at build time into the source instead would have caught the
    same drift, but only as a side effect: Update-ModuleManifest reserialises
    the whole file, dropping the comments that explain why the lists are
    explicit and writing VariablesToExport as a commented-out line, and it
    stamps a generation timestamp in, so every run leaves the working tree
    dirty.
.PARAMETER OutputPath
    The destination the module will be written to. A "PSToolkit" folder is
    appended if the path does not already end with it.
.PARAMETER SkipTests
    Build without running the Pester suite. Intended for a machine where Pester
    genuinely is not available, and it must be asked for deliberately: the
    resulting build is unverified, and without this switch a missing Pester
    aborts the build rather than producing one.
.EXAMPLE
    .\Build-Module.ps1 -OutputPath "C:\ModuleOutput"
    Runs the test suite, then builds to C:\ModuleOutput\PSToolkit.
.EXAMPLE
    .\Build-Module.ps1 -OutputPath "C:\ModuleOutput" -SkipTests
    Builds without testing, which the output states plainly. Use this knowing
    the result is unverified.
.NOTES
    Requires write access to the destination path.
    WARNING: This script removes all existing content at the destination path.

    Tests/ is not copied. The suite exercises the repository layout rather than
    the installed module, and PSToolkit.psd1 claims no dependency on it; the
    licence is copied because an MIT-licensed module distributed without its
    licence text is a licensing problem, not a tidiness one.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]
    $OutputPath,

    [Parameter()]
    [switch]
    $SkipTests
)

# -------------------------------------------------------------------------
# Resolve paths up front. $ModuleRoot used to be assigned in Step 1, after
# Step 0 referenced it, so the test step failed with a null Path.
# -------------------------------------------------------------------------
$ModuleRoot   = Split-Path -Parent $PSScriptRoot
$PublicFolder = Join-Path -Path $ModuleRoot -ChildPath "Public"
$ManifestPath = Join-Path -Path $ModuleRoot -ChildPath "PSToolkit.psd1"

# -------------------------------------------------------------------------
# Step 0: Run the Pester suite; refuse to build an unverified module
# -------------------------------------------------------------------------
# Import Pester rather than merely listing it: [PesterConfiguration] cannot
# resolve from a module that is available but not loaded, and that error is
# non-terminating, so the test step was skipped while the build reported success.
#
# A missing Pester is a failure, not a warning. The old behaviour warned and
# carried on, which meant an unverified build was indistinguishable from a
# verified one in the output. -SkipTests is the way to ask for that on purpose.
if ($SkipTests) {
    Write-Warning "Tests skipped by request. This build is UNVERIFIED."
}
else {
    $pester = Import-Module Pester -MinimumVersion 5.0.0 -PassThru -ErrorAction SilentlyContinue

    if (-not $pester) {
        throw @"
Build aborted: Pester 5 or later is not available, so the suite could not run
and this build would be unverified.

Install it with:
    Install-Module Pester -Scope CurrentUser -MinimumVersion 5.0.0

To build anyway, having accepted that nothing was tested, pass -SkipTests.
"@
    }

    Write-Host "Running Pester unit tests..." -ForegroundColor Cyan

    $PesterConfig = [PesterConfiguration]::Default
    $PesterConfig.Run.Path = Join-Path -Path $ModuleRoot -ChildPath "Tests"
    $PesterConfig.Output.Verbosity = 'Normal'
    # PassThru is what makes the counts below real. Without it Pester returns
    # $null, every total reads 0, and a failing suite is reported as a pass.
    $PesterConfig.Run.PassThru = $true
    $testResult = Invoke-Pester -Configuration $PesterConfig

    if ($null -eq $testResult) {
        throw "Build aborted: Pester returned no result, so the suite's outcome is unknown."
    }

    # A test file that cannot be parsed, or that fails during discovery, produces a
    # failed *container* rather than a failed test. Checking FailedCount alone reports
    # a broken suite as green and lets the build continue.
    $FailureCount = $testResult.FailedCount + $testResult.FailedContainersCount + $testResult.FailedBlocksCount

    if ($FailureCount -gt 0) {
        throw "Build aborted: $($testResult.FailedCount) test(s) failed, $($testResult.FailedContainersCount) container(s) failed to run, $($testResult.FailedBlocksCount) block(s) failed."
    }

    Write-Host "All $($testResult.TotalCount) tests passed." -ForegroundColor Green
}
# -------------------------------------------------------------------------

if (Test-Path -Path $PublicFolder) {
    Write-Verbose "Parsing Public functions and aliases from: $PublicFolder"

    $PublicFiles = Get-ChildItem -Path $PublicFolder -Filter "*.ps1" -File
    $DiscoveredFunctions = [System.Collections.Generic.List[string]]::new()
    $DiscoveredAliases   = [System.Collections.Generic.List[string]]::new()

    foreach ($File in $PublicFiles) {
        $Tokens = $null
        $Errors = $null
        $Ast = [System.Management.Automation.Language.Parser]::ParseFile($File.FullName, [ref]$Tokens, [ref]$Errors)

        if ($Errors) {
            Write-Warning "Syntax error in '$($File.Name)'. Skipping AST extraction for this file."
            continue
        }

        # Find function definitions matching Verb-Noun pattern
        $Functions = $Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
        foreach ($Func in $Functions) {
            if ($Func.Name -like '*-*') {
                $DiscoveredFunctions.Add($Func.Name)
            }
        }

        # Find Set-Alias commands
        $Commands = $Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)
        foreach ($Cmd in $Commands) {
            if ($Cmd.GetCommandName() -eq 'Set-Alias') {
                $NameParam = $Cmd.CommandElements | Where-Object { $_.Extent.Text -notlike 'Set-Alias' -and $_.Extent.Text -notlike '-*' } | Select-Object -First 1
                if ($NameParam) {
                    $AliasName = $NameParam.Extent.Text.Trim("'", '"')
                    $DiscoveredAliases.Add($AliasName)
                }
            }
        }
    }

    $FunctionsToExport = $DiscoveredFunctions | Sort-Object -Unique
    $AliasesToExport   = $DiscoveredAliases | Sort-Object -Unique

    # This module is a script module: everything lives in Public/ as a function, so
    # there are no cmdlets to export and no module-scope variables to publish.
    # Declared rather than left undefined so the conditional splat later has
    # something defined to test under Set-StrictMode.
    $CmdletsToExport   = @()
    $VariablesToExport = @()

    Write-Verbose "Found $( $FunctionsToExport.Count ) functions and $( $AliasesToExport.Count ) aliases to export."

    # Deliberately NOT writing these to $ManifestPath here. The update is applied
    # to the copied manifest in Step 4, after the destination exists.
}
else {
    throw "Build aborted: no Public/ folder at $PublicFolder, so there is nothing to build."
}

# -------------------------------------------------------------------------
# Step 2: Prepare Destination Directory
# -------------------------------------------------------------------------
# Ensure path ends with PSToolkit
if (-not $OutputPath.EndsWith("PSToolkit")) {
    $OutputPath = Join-Path -Path $OutputPath -ChildPath "PSToolkit"
    Write-Verbose "Adjusted output path to: $OutputPath"
}

# Remove existing content if any exists
if (Test-Path -Path $OutputPath) {
    Write-Warning "Removing existing content at: $OutputPath"
    Remove-Item -Path $OutputPath -Recurse -Force
}

# Create fresh output directory
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
Write-Verbose "Created output directory: $OutputPath"

# Define source and destination paths
$PrivateFolder = Join-Path -Path $ModuleRoot -ChildPath "Private"
$ScriptsFolder = Join-Path -Path $ModuleRoot -ChildPath "Scripts"

$DestPublicFolder  = Join-Path -Path $OutputPath -ChildPath "Public"
$DestPrivateFolder = Join-Path -Path $OutputPath -ChildPath "Private"
$DestScriptsFolder = Join-Path -Path $OutputPath -ChildPath "Scripts"

foreach ($Folder in @($DestPublicFolder, $DestPrivateFolder, $DestScriptsFolder)) {
    New-Item -Path $Folder -ItemType Directory -Force | Out-Null
    Write-Verbose "Created directory: $Folder"
}

# -------------------------------------------------------------------------
# Step 3: Copy Module Artifacts
# -------------------------------------------------------------------------
$ModuleFiles = @(
    "PSToolkit.psd1",
    "PSToolkit.psm1"
)

foreach ($File in $ModuleFiles) {
    $SourceFile = Join-Path -Path $ModuleRoot -ChildPath $File
    $DestFile   = Join-Path -Path $OutputPath -ChildPath $File
    Copy-Item -Path $SourceFile -Destination $DestFile -Force
    Write-Verbose "Copied: $File"
}

# Copy Public functions
if (Test-Path -Path $PublicFolder) {
    Copy-Item -Path "$PublicFolder\*.ps1" -Destination $DestPublicFolder -Force
    Write-Verbose "Copied Public functions"
}

# Copy Private functions
if (Test-Path -Path $PrivateFolder) {
    Copy-Item -Path "$PrivateFolder\*.ps1" -Destination $DestPrivateFolder -Force
    Write-Verbose "Copied Private functions"
}

# Copy Scripts
if (Test-Path -Path $ScriptsFolder) {
    Copy-Item -Path "$ScriptsFolder\*.ps1" -Destination $DestScriptsFolder -Force -Exclude "Build-Module.ps1"
    Write-Verbose "Copied Scripts"
}

# Copy README.md if it exists
$ReadmePath = Join-Path -Path $ModuleRoot -ChildPath "README.md"
if (Test-Path -Path $ReadmePath) {
    Copy-Item -Path $ReadmePath -Destination $OutputPath -Force
    Write-Verbose "Copied README.md"
}

# The licence travels with the module. An MIT-licensed module distributed without
# its licence text is a licensing problem, not a tidiness one, and the manifest's
# LicenseUri only helps someone who already has the folder open.
$LicensePath = Join-Path -Path $ModuleRoot -ChildPath "LICENSE"
if (Test-Path -Path $LicensePath) {
    Copy-Item -Path $LicensePath -Destination $OutputPath -Force
    Write-Verbose "Copied LICENSE"
}

# -------------------------------------------------------------------------
# Step 4: write the discovered exports into the COPIED manifest
# -------------------------------------------------------------------------
# The repository's PSToolkit.psd1 is hand-owned and is never touched by a build.
# What is derived from Public/ is applied here, to the copy, so the source file
# keeps its comments, keeps VariablesToExport as an explicit array, and does not
# gain a generation timestamp that would make every run a diff.
#
# Tests/PSToolkit.tests.ps1 checks the source manifest against Public/ directly,
# so forgetting an export still fails the build - as a named test failure rather
# than as a mysteriously rewritten file.
$BuiltManifest = Join-Path -Path $OutputPath -ChildPath "PSToolkit.psd1"

# Only non-empty export lists are passed. Update-ModuleManifest validates its own
# parameters and rejects an empty collection - "the argument is null, empty, or an
# element contains a null value" - so passing @() for a list with nothing in it
# aborts the build. Omitting a parameter leaves the copied value alone.
$UpdateParams = @{
    Path              = $BuiltManifest
    FunctionsToExport = $FunctionsToExport
}

if ($AliasesToExport)   { $UpdateParams['AliasesToExport']   = $AliasesToExport }
if ($CmdletsToExport)   { $UpdateParams['CmdletsToExport']   = $CmdletsToExport }
if ($VariablesToExport) { $UpdateParams['VariablesToExport'] = $VariablesToExport }

Update-ModuleManifest @UpdateParams
Write-Verbose "Applied derived exports to the built manifest: $BuiltManifest"

# The built module is the thing a user imports, so it is the thing worth checking.
# A manifest that does not load, or whose exports do not match what is in the
# folder, is a failed build even though every file copied without error.
try {
    $built = Test-ModuleManifest -Path $BuiltManifest -ErrorAction Stop
    $count = @($built.ExportedFunctions.Keys).Count
    Write-Host "Built manifest validated: $($built.Name) $($built.Version), $count function(s)." -ForegroundColor Green
}
catch {
    throw "Build aborted: the manifest it produced does not validate. $($_.Exception.Message)"
}

Write-Host "Module successfully built and copied to: $OutputPath" -ForegroundColor Green
