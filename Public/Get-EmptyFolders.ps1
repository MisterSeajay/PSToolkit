function Get-EmptyFolders {
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo])]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Path to search for empty folders")]
        [ValidateScript({ Test-Path $_ })]
        [string]$Path,

        [Parameter(HelpMessage = "Wildcard pattern to exclude from search")]
        [string]$Exclude
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
                # Check exclusion pattern if specified
                if ($PSBoundParameters.ContainsKey('Exclude') -and [string]::IsNullOrWhiteSpace($Exclude) -eq $false) {
                    if ($dir.FullName -like $Exclude) {
                        continue
                    }
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