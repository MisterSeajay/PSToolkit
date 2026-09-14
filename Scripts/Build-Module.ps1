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
# Step 0: Run Pester tests for the module; exit on failures
# -------------------------------------------------------------------------
if (Get-Module -ListAvailable -Name Pester) {
    Write-Host "Running Pester unit tests..." -ForegroundColor Cyan
    $testResult = Invoke-Pester -Path (Join-Path $ModuleRoot "Tests") -PassThru
    if ($testResult.FailedCount -gt 0) {
        throw "Build aborted: $($testResult.FailedCount) test(s) failed."
    }
}

# -------------------------------------------------------------------------
# Step 1: Update .psd1 Manifest Exports using AST Parsing
# -------------------------------------------------------------------------
$ModuleRoot   = Split-Path -Parent $PSScriptRoot
$PublicFolder = Join-Path -Path $ModuleRoot -ChildPath "Public"
$ManifestPath = Join-Path -Path $ModuleRoot -ChildPath "PSToolkit.psd1"

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

    Write-Verbose "Found $( $FunctionsToExport.Count ) functions and $( $AliasesToExport.Count ) aliases to export."

    # Update manifest in source root before copying
    $UpdateParams = @{
        Path              = $ManifestPath
        FunctionsToExport = $FunctionsToExport
        AliasesToExport   = if ($AliasesToExport) { $AliasesToExport } else { @() }
        VariablesToExport = @()
        CmdletsToExport   = @()
    }

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