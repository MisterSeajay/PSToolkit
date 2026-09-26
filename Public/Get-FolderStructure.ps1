function Get-FolderStructure {
    <#
    .SYNOPSIS
        Generates a custom visual folder tree structure with exclusion support.
    .DESCRIPTION
        Displays a graphical directory tree. By default, both directories and files are shown.
        Use -Directory to output only folders, or -File to output only files.

        The tree is written to the host with Write-Host rather than returned to the
        pipeline, so it cannot be captured, piped or assigned. To work with the
        structure as data, enumerate the filesystem yourself.
    .PARAMETER Path
        The directory to use as the tree root. Accepts pipeline input and must exist.
        Defaults to the current location.
    .PARAMETER Exclude
        One or more wildcard patterns matched against each item's name, not its
        full path, following the Get-ChildItem -Exclude convention. A directory
        that matches is pruned, so its contents are not walked. Defaults to .venv,
        venv, node_modules, .git, __pycache__, .pytest_cache, bin and obj.
    .PARAMETER MaxDepth
        How many levels below the root to render. The default renders the whole tree.
    .PARAMETER Directory
        Render directories only, omitting files. Cannot be combined with -File.
    .PARAMETER File
        Render files only. Directories are not descended into. Cannot be combined
        with -Directory.
    .EXAMPLE
        Get-FolderStructure -Path . -Exclude ".venv", "node_modules", ".git"
    .EXAMPLE
        tree -Directory -MaxDepth 2
    .NOTES
        Also available as the alias 'tree'.
    .LINK
        https://github.com/MisterSeajay/PSToolkit
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