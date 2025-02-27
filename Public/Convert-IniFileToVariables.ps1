<#
.SYNOPSIS
    Converts an INI file's contents to script-scoped variables.
.DESCRIPTION
    Reads an INI file and creates a script-scoped variable for each key-value pair.
.PARAMETER Path
    The path to the INI file to process.
.EXAMPLE
    Convert-IniFileToVariables -Path "C:\config.ini"
    # If config.ini contains "Name=Value", a $Name variable with "Value" will be created.
.EXAMPLE
    "C:\config.ini" | Convert-IniFileToVariables
    # Process the INI file via pipeline input.
.NOTES
    - Creates variables in the Script scope without removing them later
    - Does not handle comments or complex INI structures
#>
function Convert-IniFileToVariables {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true,
                  Position=0,
                  ValueFromPipeline=$true,
                  HelpMessage="Path to the INI file to process")]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]
        $Path
    )

    begin {
        Set-StrictMode -Version 2
    }
    
    process {
        try {
            $Content = Get-Content -Path $Path -ErrorAction Stop
            
            $Content | Select-String -SimpleMatch "=" | ForEach-Object {
                try {
                    $Line = $_.ToString()
                    $Name = ($Line -split('=', 2))[0].Trim()
                    $Value = ($Line -split('=', 2))[1].Trim()
                    
                    if (-not [string]::IsNullOrWhiteSpace($Name)) {
                        New-Variable -Scope Script -Name $Name -Value $Value -Force -WhatIf:$false
                        Write-Verbose "Created variable: $Name = $Value"
                    }
                }
                catch {
                    Write-Warning "Error processing line '$Line': $_"
                }
            }
        }
        catch {
            Write-Error "Error reading INI file '$Path': $_"
        }
    }
}