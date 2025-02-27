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
.EXAMPLE
    Get-FolderSize | Sort-Object -Property SizeMB -Descending | Select-Object -First 5

    Returns the five largest subdirectories in the current location.
.NOTES
    - Size calculation includes all files in subdirectories
    - May be slow for large directory structures
    - Requires read permissions for all subdirectories
#>
function Get-FolderSize {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position=0, 
                  HelpMessage="Path to examine for folder sizes")]
        [ValidateScript({Test-Path $_})]
        [string]
        $Path = (Get-Location).FullName
    )

    begin {
        Set-StrictMode -Version 2
    }

    process {
        try {
            $Folders = Get-ChildItem -Path $Path -Directory -ErrorAction Stop

            foreach($Folder in $Folders) {
                try {
                    $Size = (Get-ChildItem -LiteralPath $Folder.FullName -File -Recurse -ErrorAction Continue | 
                             Measure-Object -Sum -Property Length).Sum
                    
                    # Handle case where no files were found (null sum)
                    if ($null -eq $Size) { $Size = 0 }
                    
                    $Object = [PSCustomObject]@{
                        SizeMB = [math]::Round($Size/1MB, 2)
                        Name = $Folder.Name
                        FullName = $Folder.FullName
                    }
                    Write-Output $Object
                }
                catch {
                    Write-Warning "Error processing folder $($Folder.FullName): $_"
                }
            }
        }
        catch {
            Write-Error "Error accessing path $Path`: $_"
        }
    }
}