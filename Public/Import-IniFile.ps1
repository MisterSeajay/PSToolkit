<#
.SYNOPSIS
    Imports an INI file's key-value pairs as PowerShell variables.
.DESCRIPTION
    Reads an INI file and creates a variable for each key-value pair, in the
    scope given by -Scope. Section headers are ignored, and lines whose first
    non-blank character is ';' or '#' are treated as comments and skipped.

    A key is used as the variable name verbatim, so a key that is not a legal
    PowerShell identifier produces a warning and is skipped rather than
    aborting the file.

    The variables are the result, and nothing is written to the pipeline. A file
    containing "Port=8080" leaves $Port set to '8080' once the command returns.
.PARAMETER Path
    The path to the INI file to process.
.PARAMETER Scope
    The PowerShell scope to create the variables in. Defaults to Global.

    Global is the default rather than a nicety: a function inside a module runs in
    the module's own scope, so -Scope Script and -Scope Local create the
    variables where the caller cannot see them, and where they disappear when the
    module is unloaded. Global is the only value that makes the variables visible
    to the caller, which is the whole point of the command. The other two are
    offered because they are the right choice in some host modules, but expect
    them to be invisible from a normal caller.
.EXAMPLE
    Import-IniFile -Path .\config.ini
    Creates a variable per key in the global scope, so a file containing
    "Port=8080" leaves $Port set to '8080'.
.EXAMPLE
    ".\config.ini" | Import-IniFile
    Process the INI file via pipeline input.
.NOTES
    Variables are created with -Force, so an existing writable variable of the
    same name is overwritten. A key that names a read-only automatic variable,
    such as 'Host' or 'PID', cannot be overwritten even with -Force: that line is
    reported as a warning and skipped, and the rest of the file still loads. Key
    names are not otherwise sanitised, so keep that in mind before pointing this
    at an untrusted file.
.LINK
    https://github.com/MisterSeajay/PSToolkit
#>
function Import-IniFile {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true,
                  Position=0,
                  ValueFromPipeline=$true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]
        $Path,

        [Parameter(Position=1)]
        [ValidateSet('Global','Script','Local')]
        [string]
        $Scope = 'Global'
    )

    begin {
        Set-StrictMode -Version 2.0
    }
    
    process {
        try {
            $Content = Get-Content -Path $Path -ErrorAction Stop
            
            $Content | Select-String -SimpleMatch "=" | ForEach-Object {
                try {
                    $Line = $_.ToString()

                    # A comment may still contain '=', so comments are dropped here
                    # rather than by the filter above. Without this, '; Port=8080'
                    # would try to create a variable named '; Port'.
                    if ($Line.TrimStart().StartsWith(';') -or $Line.TrimStart().StartsWith('#')) {
                        return
                    }

                    $Name = ($Line -split('=', 2))[0].Trim()
                    $Value = ($Line -split('=', 2))[1].Trim()
                    
                    if (-not [string]::IsNullOrWhiteSpace($Name)) {
                        # -ErrorAction Stop is what makes the catch above reachable.
                        # A read-only name such as Host is a non-terminating error, so
                        # without it the raw error record escapes and a caller running
                        # with -ErrorAction Stop loses the rest of the file.
                        New-Variable -Scope $Scope -Name $Name -Value $Value -Force -WhatIf:$false -ErrorAction Stop
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

    end { }  # Nothing to finalise: each path is read wholly in process.
}
