function Format-Tree {
    <#
    .SYNOPSIS
        Draws a directory hierarchy to the host.
    .DESCRIPTION
        Renders objects that carry a Depth property as an indented tree, in the
        style of the Windows tree command. Nodes are drawn in the order received,
        with a Depth property deciding indentation and connector, so any
        depth-first sequence of items can be drawn, not only one from
        Get-FolderStructure.

        A node is drawn as the last of its siblings when no further sibling
        follows it, so Depth alone is enough to reconstruct the shape. Note that
        lastness is a property of the whole sequence, not of neighbouring items: a
        directory is followed by its own children rather than by its next sibling,
        and two nodes at the same depth in different subtrees are not siblings.

        Output goes to the host rather than the pipeline, because it is formatted
        for a person to read. To work with the structure as data, use
        Get-FolderStructure directly.
    .PARAMETER InputObject
        The nodes to draw, normally piped from Get-FolderStructure. Each should
        expose Name, Depth and PSIsContainer.
    .PARAMETER Path
        Convenience for a one-shot draw: resolves the hierarchy with
        Get-FolderStructure and renders the result. Equivalent to
        Get-FolderStructure -Path <Path> | Format-Tree. This is what the 'tree'
        alias uses. Defaults to the current location, so a bare 'tree' draws the
        directory you are standing in. Ignored when nodes arrive on the pipeline,
        which take precedence.
    .PARAMETER Exclude
        Wildcard patterns to exclude by name, used only with -Path. Forwarded to
        Get-FolderStructure.
    .PARAMETER MaxDepth
        Levels below the root to draw, used only with -Path. Forwarded to
        Get-FolderStructure.
    .PARAMETER Directory
        Draw directories only, used only with -Path. Forwarded to Get-FolderStructure.
    .PARAMETER File
        Draw files only, used only with -Path. Forwarded to Get-FolderStructure.
    .EXAMPLE
        Get-FolderStructure -Path C:\Projects | Format-Tree
        Draws the tree for C:\Projects.
    .EXAMPLE
        Format-Tree -Path C:\Projects -Directory -MaxDepth 2
        Draws the root and its immediate child directories only.
    .EXAMPLE
        Get-FolderStructure -Exclude '*.log' | Format-Tree
        Draws a tree with log files omitted.
    .NOTES
        Directories are drawn with a trailing separator and in a different colour
        from files. A node whose Name is empty, such as a drive root, falls back
        to its FullName.

        With neither pipeline input nor -Path, the current location is drawn.
        PowerShell cannot distinguish an empty pipeline from no pipeline, so a
        pipeline that yields nothing also draws the current location rather than
        nothing. To draw an empty result, check the count before piping.
    .LINK
        https://github.com/MisterSeajay/PSToolkit
    #>
    # Write-Host is the point of this command: it renders a tree for a person to
    # read, where the output is deliberately not pipeline data. See AGENTS.md 1.3.
    [CmdletBinding(DefaultParameterSetName = 'FromPipeline')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [OutputType([System.Void])]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [AllowNull()]
        [PSObject]$InputObject,

        [Parameter(ParameterSetName = 'FromPath', Position = 0)]
        [System.String]$Path,

        [System.String[]]$Exclude = @('.venv', 'venv', 'node_modules', '.git', '__pycache__', '.pytest_cache', 'bin', 'obj'),

        [System.Int32]$MaxDepth = [System.Int32]::MaxValue,

        [System.Management.Automation.SwitchParameter]$Directory,

        [System.Management.Automation.SwitchParameter]$File
    )

    begin {
        Set-StrictMode -Version 2.0

        # Box-drawing glyphs are built from [char] codes rather than literal
        # characters, so the rendering cannot depend on how the file was decoded.
        $script:BranchConnector = "$([char]0x251C)$([char]0x2500)$([char]0x2500) " # |--
        $script:LastConnector   = "$([char]0x2514)$([char]0x2500)$([char]0x2500) " # `--
        $script:VerticalPrefix  = "$([char]0x2502)   "                              # |
        $script:BlankPrefix     = '    '

        $script:Nodes = [System.Collections.Generic.List[PSObject]]::new()
    }

    process {
        if ($null -ne $InputObject) {
            [void]$script:Nodes.Add($InputObject)
        }
    }

    end {
        # Nothing arrived on the pipeline, so draw the hierarchy instead of
        # nothing. This is what makes a bare `tree` work: without it, an unbound
        # -Path and an empty pipeline are the same case, and the command it
        # replaces its name from would print the directory you are standing in.
        if ($script:Nodes.Count -eq 0) {
            $Splat = @{
                Exclude  = $Exclude
                MaxDepth = $MaxDepth
            }
            # Omit Path entirely when it was not bound, so that Get-FolderStructure
            # applies its own default of the current location. Assigning '.' here
            # would be equivalent today, but would hard-code a second default that
            # the two commands could then drift apart on.
            if ($PSBoundParameters.ContainsKey('Path')) { $Splat['Path'] = $Path }
            if ($Directory) { $Splat['Directory'] = $true }
            if ($File) { $Splat['File'] = $true }

            foreach ($node in (Get-FolderStructure @Splat)) {
                [void]$script:Nodes.Add($node)
            }
        }

        if ($script:Nodes.Count -eq 0) {
            return
        }

        # $LastFlags[i] is true when node i is the final member of its sibling group.
        #
        # A single forward pass with a stack of "still open" nodes. When a node
        # arrives at depth d:
        #   - anything open deeper than d has finished, so it was the last of its
        #     siblings, and any descendants it had are closed out with it;
        #   - anything already open at depth d has just gained a sibling, so it is
        #     not last.
        # Whatever is still open when the input ends is last.
        #
        # Two simpler rules both look plausible and are wrong. Comparing only the
        # next node fails for a node that has children, because the next node is
        # its own child. Comparing depths across the whole sequence fails too,
        # because two nodes at the same depth in different subtrees are not siblings.
        #
        # Note the distinct name: PowerShell variable names are case-insensitive, so
        # a scalar named $isLast would overwrite this array on first use.
        $LastFlags = [bool[]]::new($script:Nodes.Count)
        $OpenAt = [System.Collections.Generic.List[int]]::new()

        for ($i = 0; $i -lt $script:Nodes.Count; $i++) {
            $nodeDepth = [int]$script:Nodes[$i].Depth

            # Close out nodes strictly deeper than this one: they are descendants,
            # and are the last of their own sibling groups. The node at exactly
            # $nodeDepth is the previous sibling, not a descendant, so it stays on
            # the stack and is marked below.
            while ($OpenAt.Count -gt ($nodeDepth + 1)) {
                $LastFlags[$OpenAt[$OpenAt.Count - 1]] = $true
                $OpenAt.RemoveAt($OpenAt.Count - 1)
            }

            if ($nodeDepth -lt $OpenAt.Count) {
                $LastFlags[$OpenAt[$nodeDepth]] = $false
            }

            while ($OpenAt.Count -lt $nodeDepth) { [void]$OpenAt.Add(-1) }
            if ($nodeDepth -lt $OpenAt.Count) { $OpenAt[$nodeDepth] = $i } else { [void]$OpenAt.Add($i) }
        }

        foreach ($openIndex in $OpenAt) {
            if ($openIndex -ge 0) { $LastFlags[$openIndex] = $true }
        }

        # $LastAtDepth[i] records whether the node seen at depth i was the final
        # one among its siblings, which is what decides the continuation prefix.
        $LastAtDepth = [System.Collections.Generic.List[bool]]::new()

        for ($i = 0; $i -lt $script:Nodes.Count; $i++) {
            $node       = $script:Nodes[$i]
            $depth      = [int]$node.Depth
            $nodeIsLast = $LastFlags[$i]

            $name = [string]$node.Name
            if ($node.PSIsContainer) { $name += '/' }

            $colour = if ($depth -eq 0) { [System.ConsoleColor]::Yellow }
                      elseif ($node.PSIsContainer) { [System.ConsoleColor]::Cyan }
                      else { [System.ConsoleColor]::Gray }

            if ($depth -eq 0) {
                Write-Host $name -ForegroundColor $colour
            }
            else {
                $Prefix = ''
                # Level 0 is the root, which contributes no prefix; the ancestors that
                # matter are levels 1 through depth-1.
                for ($level = 1; $level -lt $depth; $level++) {
                    $ancestorWasLast = $true
                    if ($level -lt $LastAtDepth.Count) {
                        $ancestorWasLast = $LastAtDepth[$level]
                    }
                    $Prefix += if ($ancestorWasLast) { $script:BlankPrefix } else { $script:VerticalPrefix }
                }

                $Connector = if ($nodeIsLast) { $script:LastConnector } else { $script:BranchConnector }
                Write-Host "$Prefix$Connector$name" -ForegroundColor $colour
            }

            while ($LastAtDepth.Count -le $depth) {
                [void]$LastAtDepth.Add($true)
            }
            $LastAtDepth[$depth] = $nodeIsLast
        }
    }
}

Set-Alias -Name tree -Value Format-Tree -Description "PSToolkit visual folder tree replacement"
