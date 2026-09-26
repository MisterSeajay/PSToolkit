function Get-EmptyFolders {
    <#
    .SYNOPSIS
        Finds directories that contain nothing at all.
    .DESCRIPTION
        Recursively scans a path and returns a System.IO.DirectoryInfo object for
        every directory that holds neither files nor subdirectories. Emits nothing
        when no empty directories are found.

        Directories that cannot be read are skipped with a warning instead of
        terminating the walk, so one protected subdirectory does not stop the scan.
    .PARAMETER Path
        The path to search. Accepts pipeline input, and must exist if supplied.
        Defaults to the current location.
    .PARAMETER Exclude
        One or more wildcard patterns matched against each candidate's name, not
        its full path, following the Get-ChildItem -Exclude convention. Matching
        directories are omitted from the results. No pattern is applied by
        default.
    .EXAMPLE
        Get-EmptyFolders
        Searches the current location and everything beneath it.
    .EXAMPLE
        Get-ChildItem C:\Projects -Directory | Get-EmptyFolders
        Searches each project directory, taking Path from the pipeline.
    .EXAMPLE
        Get-EmptyFolders -Path C:\Projects -Exclude 'node_modules', '.git'
        Searches C:\Projects, omitting directories with either of those names at
        any depth.
    .EXAMPLE
        Get-EmptyFolders -Path C:\Projects -Exclude '*Cache*'
        Omits every directory whose name contains Cache, such as AppData\Local\Cache.
    .NOTES
        Returns objects to the pipeline, so the result can be filtered, counted or
        piped elsewhere. Output is System.IO.DirectoryInfo, not FileInfo.
        Requires read access to each directory; access denials surface as warnings.
    .LINK
        https://github.com/MisterSeajay/PSToolkit
    #>
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo])]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Path to search for empty folders")]
        [ValidateScript({ Test-Path $_ })]
        [string]$Path,

        [Parameter(HelpMessage = "Wildcard patterns matched against directory names to skip")]
        [string[]]$Exclude
    )

    begin {
        Set-StrictMode -Version 2.0
    }

    process {
        if (-not $PSBoundParameters.ContainsKey('Path')) {
            $Path = (Get-Location).Path
        }

        try {
            $resolvedPath = Convert-Path -LiteralPath $Path -ErrorAction Stop
            $directories = Get-ChildItem -LiteralPath $resolvedPath -Directory -Recurse -ErrorAction Stop

            foreach ($dir in $directories) {
                # Skip directories whose name matches an -Exclude pattern, using the
                # same Get-ChildItem -Exclude convention as Get-FolderStructure.
                if (testNameExcluded -Name $dir.Name -Pattern $Exclude) {
                    continue
                }

                try {
                    # Fast .NET check: stops at 1st item instead of allocating array
                    $dirInfo = [System.IO.DirectoryInfo]::new($dir.FullName)
                    $hasContent = $dirInfo.EnumerateFileSystemInfos().GetEnumerator().MoveNext()

                    if (-not $hasContent) {
                        Write-Output $dirInfo
                    }
                }
                catch [System.UnauthorizedAccessException] {
                    Write-Warning "Access denied reading directory '$($dir.FullName)'."
                }
                catch {
                    Write-Warning "Error processing directory '$($dir.FullName)': $_"
                }
            }
        }
        catch {
            Write-Error "Error scanning path '$Path': $_"
        }
    }
}