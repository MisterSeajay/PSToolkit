<#
.SYNOPSIS
    Builds the PSToolkit module and copies it to a specified output path.
.DESCRIPTION
    Copies all necessary module files to the specified destination path.
    Creates required directory structure at the destination if it doesn't exist.
    Ensures the module is placed in a PSToolkit folder.
    Removes any existing content at the destination to ensure a clean build.
.PARAMETER OutputPath
    The destination path where the module will be saved.
    If it doesn't end with "PSToolkit", that folder will be appended.
.EXAMPLE
    .\Build-Module.ps1 -OutputPath "C:\ModuleOutput"
    Builds the module and copies it to C:\ModuleOutput\PSToolkit
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
$ModuleRoot = Split-Path -Parent $PSScriptRoot
$PublicFolder = Join-Path -Path $ModuleRoot -ChildPath "Public"
$PrivateFolder = Join-Path -Path $ModuleRoot -ChildPath "Private"
$ScriptsFolder = Join-Path -Path $ModuleRoot -ChildPath "Scripts"

# Create destination structure
$DestPublicFolder = Join-Path -Path $OutputPath -ChildPath "Public"
$DestPrivateFolder = Join-Path -Path $OutputPath -ChildPath "Private"
$DestScriptsFolder = Join-Path -Path $OutputPath -ChildPath "Scripts"

foreach ($Folder in @($DestPublicFolder, $DestPrivateFolder, $DestScriptsFolder)) {
    New-Item -Path $Folder -ItemType Directory -Force | Out-Null
    Write-Verbose "Created directory: $Folder"
}

# Copy module files
$ModuleFiles = @(
    "PSToolkit.psd1"
    "PSToolkit.psm1"
)

foreach ($File in $ModuleFiles) {
    $SourceFile = Join-Path -Path $ModuleRoot -ChildPath $File
    $DestFile = Join-Path -Path $OutputPath -ChildPath $File
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

Write-Host "Module successfully built and copied to: $OutputPath" -ForegroundColor Green