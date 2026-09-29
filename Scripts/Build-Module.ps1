<#
.SYNOPSIS
    Builds the PSToolkit module, updates its manifest exports, and copies it to a specified output path.
.DESCRIPTION
    1. Parses Public/ scripts using PowerShell AST to discover exported functions and Set-Alias definitions.
    2. Updates PSToolkit.psd1 with discovered FunctionsToExport and AliasesToExport.
    3. Copies all module files to the specified destination path.
    4. Ensures the module is placed in a PSToolkit folder.
    5. Removes any existing content at the destination to ensure a clean build.
.PARAMETER OutputPath
    The destination path where the module will be saved.
    If it doesn't end with "PSToolkit", that folder will be appended.
.EXAMPLE
    .\Build-Module.ps1 -OutputPath "C:\ModuleOutput"
    Builds the module, updates exports, and copies it to C:\ModuleOutput\PSToolkit
.NOTES
    Requires write access to the destination path.
    WARNING: This script will remove all existing content at the destination path.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]
    $OutputPath
)

# -------------------------------------------------------------------------
# Resolve paths up front. $ModuleRoot used to be assigned in Step 1, after
# Step 0 referenced it, so the test step failed with a null Path.
# -------------------------------------------------------------------------
$ModuleRoot   = Split-Path -Parent $PSScriptRoot
$PublicFolder = Join-Path -Path $ModuleRoot -ChildPath "Public"
$ManifestPath = Join-Path -Path $ModuleRoot -ChildPath "PSToolkit.psd1"

# -------------------------------------------------------------------------
# Step 0: Run Pester tests for the module; exit on failures
# -------------------------------------------------------------------------
# Import Pester rather than merely listing it: [PesterConfiguration] cannot
# resolve from a module that is available but not loaded, and that error is
# non-terminating, so the test step was skipped while the build reported success.
$pester = Import-Module Pester -MinimumVersion 5.0.0 -PassThru -ErrorAction SilentlyContinue

if ($pester) {
    Write-Host "Running Pester unit tests..." -ForegroundColor Cyan

    $PesterConfig = [PesterConfiguration]::Default
    $PesterConfig.Run.Path = Join-Path -Path $ModuleRoot -ChildPath "Tests"
    $PesterConfig.Output.Verbosity = 'Normal'
    $PesterConfig.Run.PassThru = $true
    $testResult = Invoke-Pester -Configuration $PesterConfig

    # A test file that cannot be parsed, or that fails during discovery, produces a
    # failed *container* rather than a failed test. Checking FailedCount alone reports
    # a broken suite as green and lets the build continue.
    $FailureCount = $testResult.FailedCount + $testResult.FailedContainersCount + $testResult.FailedBlocksCount

    if ($FailureCount -gt 0) {
        throw "Build aborted: $($testResult.FailedCount) test(s) failed, $($testResult.FailedContainersCount) container(s) failed to run, $($testResult.FailedBlocksCount) block(s) failed."
    }

    Write-Host "All $($testResult.TotalCount) tests passed." -ForegroundColor Green
}
else {
    Write-Warning "Pester 5+ not found; the test gate is being SKIPPED and this build is unverified."
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
    # Declared rather than left undefined so the conditional splat below has
    # something defined to test under Set-StrictMode.
    $CmdletsToExport   = @()
    $VariablesToExport = @()

    Write-Verbose "Found $( $FunctionsToExport.Count ) functions and $( $AliasesToExport.Count ) aliases to export."

    # Update manifest in source root before copying
    #
    # Only non-empty export lists are passed. Update-ModuleManifest validates its
    # parameters and rejects an empty collection - "the argument is null, empty, or
    # an element contains a null value" - so passing @() for a list with nothing
    # in it aborts the build. The manifest already spells out explicit empty
    # arrays for the lists this module does not export, and omitting a parameter
    # leaves the existing value alone.
    $UpdateParams = @{
        Path              = $ManifestPath
        FunctionsToExport = $FunctionsToExport
    }

    if ($AliasesToExport)   { $UpdateParams['AliasesToExport']   = $AliasesToExport }
    if ($CmdletsToExport)   { $UpdateParams['CmdletsToExport']   = $CmdletsToExport }
    if ($VariablesToExport) { $UpdateParams['VariablesToExport'] = $VariablesToExport }

    Update-ModuleManifest @UpdateParams
    Write-Verbose "Updated $ManifestPath with latest exports."
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

Write-Host "Module successfully built, manifest updated, and copied to: $OutputPath" -ForegroundColor Green
