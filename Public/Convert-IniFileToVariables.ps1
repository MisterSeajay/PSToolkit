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

.NOTES
    - Creates variables in the Script scope without removing them later
    - Does not handle comments or complex INI structures
#>
function Convert-IniFileToVariables {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [string]
        $Path
    )

    Get-Content $Path | Select-String -SimpleMatch "=" | Foreach-Object {
        $Name = ($_ -split('='))[0]
        $Value = ($_ -split('='))[1]
        New-Variable -Scope Script -Name $Name -Value $Value -WhatIf:$false
    }
}
