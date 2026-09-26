# Helper to construct nested hashtable tree nodes from filesystem paths
function buildDirectoryNode {
    param(
        [System.IO.DirectoryInfo]$DirectoryItem,
        [System.Int32]$CurrentDepth = 1
    )

    $node = @{
        Name     = "$($DirectoryItem.Name)/"
        Color    = [System.ConsoleColor]::Cyan
        Children = [System.Collections.Generic.List[System.Collections.IDictionary]]::new()
    }

    if ($CurrentDepth -ge $MaxDepth) {
        return $node
    }

    $includeDirs = -not $File.IsPresent
    if ($includeDirs) {
        $subDirs = $DirectoryItem.GetDirectories() | 
            Where-Object { $Exclude -notcontains $_.Name } | 
            Sort-Object Name

        foreach ($dir in $subDirs) {
            $childDirNode = buildDirectoryNode -DirectoryItem $dir -CurrentDepth ($CurrentDepth + 1)
            [void]$node['Children'].Add($childDirNode)
        }
    }

    $includeFiles = -not $Directory.IsPresent
    if ($includeFiles) {
        $files = $DirectoryItem.GetFiles() | 
            Where-Object { $Exclude -notcontains $_.Name } | 
            Sort-Object Name

        foreach ($file in $files) {
            [void]$node['Children'].Add(@{
                Name  = $file.Name
                Color = [System.ConsoleColor]::Gray
            })
        }
    }

    return $node
}
