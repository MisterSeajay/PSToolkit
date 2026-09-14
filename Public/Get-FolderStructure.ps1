function Get-FolderStructure {
    <#
    .SYNOPSIS
        Generates a custom visual folder tree structure with exclusion support.
    .DESCRIPTION
        Displays a graphical directory tree. By default, both directories and files are shown.
        Use -Directory to output only folders, or -File to output only files.
    .EXAMPLE
        Get-FolderStructure -Path . -Exclude ".venv", "node_modules", ".git"
    .EXAMPLE
        tree -Directory -MaxDepth 2
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [System.String]$Path = '.',

        [System.String[]]$Exclude = @('.venv', 'venv', 'node_modules', '.git', '__pycache__', '.pytest_cache', 'bin', 'obj'),

        [System.Int32]$MaxDepth = [System.Int32]::MaxValue,

        [Parameter(ParameterSetName = 'DirectoryOnly')]
        [System.Management.Automation.SwitchParameter]$Directory,

        [Parameter(ParameterSetName = 'FileOnly')]
        [System.Management.Automation.SwitchParameter]$File,

        [Parameter(ValueFromRemainingArguments = $true)]
        [System.String[]]$LegacyArgs
    )

    begin {
        # Process legacy cmd flags if passed via alias
        if ($LegacyArgs) {
            foreach ($arg in $LegacyArgs) {
                switch -Regex ($arg) {
                    '^/F$' { 
                        # /F in cmd.exe means show files (default behavior)
                    }
                    '^/A$' { 
                        # /A in cmd.exe means ASCII characters (ignored)
                    }
                    default { 
                        Write-Warning "Unrecognized legacy option '$arg' ignored." 
                    }
                }
            }
        }
    }

    process {
        $resolvedPath = Convert-Path -Path $Path
        $rootItem = Get-Item -Path $resolvedPath

        if (-not $rootItem.PSIsContainer) {
            Write-Error "Provided path '$Path' is not a directory."
            return
        }

        Write-Host "$($rootItem.Name)/" -ForegroundColor Yellow

        $treeData = buildDirectoryNode -DirectoryItem $rootItem
        showTree -Node $treeData -MaxDepth $MaxDepth
    }
}

Set-Alias -Name tree -Value Get-FolderStructure -Description "PSToolkit visual folder tree replacement"