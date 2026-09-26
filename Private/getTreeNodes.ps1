<#
.SYNOPSIS
    Emits a directory hierarchy as flat nodes, depth-first.
.DESCRIPTION
    Walks a directory and writes one object per item to the output stream, parents
    before children, with the depth recorded on each object. Directories are
    emitted before files at any given level, each group sorted by name.

    Output is streamed rather than collected, so a large tree does not have to be
    held in memory in full. The Depth property is sufficient for a caller to
    reconstruct the hierarchy, or to render it, without any further structure.
.PARAMETER DirectoryItem
    The directory to walk. Emitted as the first node, at depth 0.
.PARAMETER Depth
    The depth of DirectoryItem itself. The root call uses 0; recursion increments it.
.PARAMETER MaxDepth
    How many levels below the root to emit. The default emits the whole tree. A
    value of 1 emits the root alone, matching the previous renderer.
.PARAMETER Exclude
    Wildcard patterns tested against item names, following the Get-ChildItem
    -Exclude convention. A matching directory is not descended into.
.PARAMETER IncludeDirectories
    Emit directory nodes. Set to $false to produce a files-only listing.
.PARAMETER IncludeFiles
    Emit file nodes. Set to $false to produce a directories-only listing.
.EXAMPLE
    getTreeNodes -DirectoryItem (Get-Item 'C:\Projects') -MaxDepth 2
    Emits the root, its immediate children, and stops there.
.NOTES
    Directory names are not decorated with a trailing separator. Consumers decide
    how to present a container, usually by appending a separator.
.LINK
    https://github.com/MisterSeajay/PSToolkit
#>
function getTreeNodes {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$DirectoryItem,

        [System.Int32]$Depth = 0,

        [System.Int32]$MaxDepth = [System.Int32]::MaxValue,

        [System.String[]]$Exclude = @(),

        [System.Boolean]$IncludeDirectories = $true,

        [System.Boolean]$IncludeFiles = $true
    )

    # A drive or share root has an empty Name; fall back to the full path so the
    # node is never rendered as a bare separator.
    $displayName = $DirectoryItem.Name
    if ([string]::IsNullOrEmpty($displayName)) {
        $displayName = $DirectoryItem.FullName
    }

    [PSCustomObject]@{
        Name          = $displayName
        FullName      = $DirectoryItem.FullName
        Depth         = $Depth
        PSIsContainer = $true
    }

    # Emit children only while below the depth limit. Comparing against MaxDepth - 1
    # rather than adding to MaxDepth avoids overflowing at [int]::MaxValue.
    if ($Depth -ge ($MaxDepth - 1)) {
        return
    }

    if ($IncludeDirectories) {
        foreach ($dir in ($DirectoryItem.GetDirectories() |
                            Where-Object { -not (testNameExcluded -Name $_.Name -Pattern $Exclude) } |
                            Sort-Object Name)) {
            getTreeNodes -DirectoryItem $dir -Depth ($Depth + 1) -MaxDepth $MaxDepth `
                -Exclude $Exclude -IncludeDirectories $IncludeDirectories -IncludeFiles $IncludeFiles
        }
    }

    if ($IncludeFiles) {
        foreach ($file in ($DirectoryItem.GetFiles() |
                             Where-Object { -not (testNameExcluded -Name $_.Name -Pattern $Exclude) } |
                             Sort-Object Name)) {
            [PSCustomObject]@{
                Name          = $file.Name
                FullName      = $file.FullName
                Depth         = $Depth + 1
                PSIsContainer = $false
            }
        }
    }
}
