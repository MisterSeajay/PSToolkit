<#
.SYNOPSIS
    Gets the size of subdirectories in the specified path.
.DESCRIPTION
    Calculates the size of each subdirectory in the specified path and returns
    custom objects containing the name, formatted sizes, and full path.
.PARAMETER Path
    The path to examine. Accepts pipeline input. Defaults to the current working location.
.EXAMPLE
    Get-FolderSize
    Returns the size of all subdirectories in the current location.
.EXAMPLE
    Get-ChildItem C:\Users -Directory | Get-FolderSize
    Pipes directories directly into Get-FolderSize.
.EXAMPLE
    Get-FolderSize -Path "C:\Users" | Sort-Object SizeMB -Descending | Select-Object -First 5
    Returns the five largest subdirectories in C:\Users.
#>
function Get-FolderSize {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$Path
    )

    begin {
        Set-StrictMode -Version 2.0
    }

    process {
        # Fall back to current working directory if Path was not supplied
        if (-not $PSBoundParameters.ContainsKey('Path')) {
            $Path = (Get-Location).Path
        }

        try {
            $resolvedPath = Convert-Path -Path $Path -ErrorAction Stop
            $folders = Get-ChildItem -LiteralPath $resolvedPath -Directory -ErrorAction Stop

            foreach ($folder in $folders) {
                try {
                    # Fast .NET enumeration to bypass pipeline overhead
                    $dirInfo = [System.IO.DirectoryInfo]::new($folder.FullName)

                    # Sum lengths of all files recursively; ignore unreadable files/folders
                    $totalBytes = [int64]0
                    $files = $dirInfo.EnumerateFiles('*', [System.IO.SearchOption]::AllDirectories)

                    $enum = $files.GetEnumerator()
                    while ($enum.MoveNext()) {
                        $totalBytes += $enum.Current.Length
                    }

                    [PSCustomObject]@{
                        Name     = $folder.Name
                        SizeMB   = [math]::Round($totalBytes / 1MB, 2)
                        SizeBytes = $totalBytes
                        FullName = $folder.FullName
                    }
                }
                catch [System.UnauthorizedAccessException] {
                    Write-Warning "Access denied reading files in '$($folder.FullName)'."
                }
                catch {
                    Write-Warning "Error processing folder '$($folder.FullName)': $_"
                }
            }
        }
        catch {
            Write-Error "Error accessing path '$Path': $_"
        }
    }
}