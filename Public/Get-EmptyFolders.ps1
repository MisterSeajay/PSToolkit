<#
.SYNOPSIS
    Finds empty sub-folders under the specified path.
.DESCRIPTION
    Scans a folder hierarchy for any folders that do not contain
    other files or folders. The results are returned as DirectoryInfo
    objects.
.PARAMETER Path
    The root path to scan for empty folders. Defaults to current location.
.PARAMETER Exclude
    Path pattern to exclude from scanning.
.EXAMPLE
    Get-EmptyFolders
    Returns all empty folders under the current location.
.EXAMPLE
    Get-EmptyFolders -Path "C:\Projects" -Exclude "*\node_modules\*"
    Returns empty folders under C:\Projects, excluding any in node_modules folders.
.NOTES
    Author: Charles Joynt
#>
function Get-EmptyFolders {
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo])]
    param (
        [Parameter(Position=0, 
                  HelpMessage="Path to search for empty folders")]
        [string]
        $Path = (Get-Location),
        
        [Parameter(HelpMessage="Pattern to exclude from search")]
        [string]
        $Exclude = ""
    )

    begin {
        Set-StrictMode -Version 2
    }
    
    process {
        $Folders = Get-ChildItem -LiteralPath $Path -Directory -Recurse | 
            Where-Object { $_.FullName -notlike $Exclude }

        foreach($Folder in $Folders) {
            if(($Folder.GetFiles().Count -eq 0) -and ($Folder.GetDirectories().count -eq 0)) {
                Write-Output $Folder
            }
        }
    }
}