function Get-FolderStructure {
    <#
    .SYNOPSIS
        Returns a directory hierarchy as objects, one per item.
    .DESCRIPTION
        Walks a path and emits an object for the root directory and every item
        beneath it, with a Depth property recording each item's level. The result
        is designed to be piped: filter it, select from it, or hand it to
        Format-Tree to draw the hierarchy.

        Directories are emitted before files at each level, each group sorted by
        name. Nothing is written to the host, so the output can be captured,
        filtered or counted like any other object.

        To see a drawn tree, pipe to Format-Tree, or use the 'tree' alias.
    .PARAMETER Path
        The directory to use as the tree root. Accepts pipeline input and must
        exist. Defaults to the current location.
    .PARAMETER Exclude
        One or more wildcard patterns matched against each item's name, not its
        full path, following the Get-ChildItem -Exclude convention. A directory
        that matches is pruned, so its contents are not walked. Defaults to
        .venv, venv, node_modules, .git, __pycache__, .pytest_cache, bin and obj.
    .PARAMETER MaxDepth
        How many levels below the root to emit. The default emits the whole tree;
        1 emits the root alone.
    .PARAMETER Directory
        Emit directories only, omitting files. Cannot be combined with -File.
    .PARAMETER File
        Emit files only, omitting directories. Cannot be combined with -Directory.
    .EXAMPLE
        Get-FolderStructure -Path C:\Projects
        Returns an object per directory and file, with Depth populated.
    .EXAMPLE
        Get-FolderStructure -Path C:\Projects -Directory -MaxDepth 2
        Returns only the root and its immediate child directories.
    .EXAMPLE
        tree
        Draws the current location as a tree. The 'tree' alias is an alias for
        Format-Tree, so this is shorthand for:
        Get-FolderStructure | Format-Tree
    .NOTES
        Each object carries Name, FullName, Depth and PSIsContainer. Directory
        names carry no trailing separator; add one when presenting a container.
    .LINK
        https://github.com/MisterSeajay/PSToolkit
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([PSCustomObject])]
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
        Set-StrictMode -Version 2.0

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

        getTreeNodes -DirectoryItem $rootItem -Depth 0 -MaxDepth $MaxDepth -Exclude $Exclude `
            -IncludeDirectories (-not $File.IsPresent) `
            -IncludeFiles (-not $Directory.IsPresent)
    }
}
