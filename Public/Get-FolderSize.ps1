<#
.SYNOPSIS
    Gets the size of subdirectories in the specified path.
.DESCRIPTION
    Calculates the size of each subdirectory in the specified path and returns
    custom objects containing the name, size in MB, and full path.
.PARAMETER Path
    The path to examine. Defaults to the current location.
.EXAMPLE
    Get-FolderSize

    Returns the size of all subdirectories in the current location.
.EXAMPLE
    Get-FolderSize -Path "C:\Users"

    Returns the size of all subdirectories in C:\Users.
.NOTES
    - Size calculation includes all files in subdirectories
    - May be slow for large directory structures
    - Requires read permissions for all subdirectories
#>
function Get-FolderSize {
    [CmdletBinding()]
    param(
        [Parameter()]
        $Path = (Get-Location).Fullname
    )

    $Folders = Get-ChildItem -Path $Path -Directory

    foreach($Folder in $Folders){
        $Size = (Get-ChildItem -LiteralPath $Folder.Fullname -File -Recurse | Measure-Object -Sum -Property Length).Sum
        $Object = [PSCustomObject]@{
            SizeMB = [math]::Round($Size/1MB,2)
            Name = $Folder.Name
            Fullname = $Folder.Fullname
        }
        Write-Output $Object
    }
}