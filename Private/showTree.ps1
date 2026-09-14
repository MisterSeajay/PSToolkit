function showTree {
    <#
    .SYNOPSIS
        Private helper to recursively render nested Hashtable/Dictionary trees.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [System.Collections.IDictionary]$Node,

        [System.String]$Indent = '',

        [System.Int32]$CurrentDepth = 1,

        [System.Int32]$MaxDepth = [System.Int32]::MaxValue
    )

    if ($CurrentDepth -gt $MaxDepth) { 
        return 
    }

    if (-not $Node.Contains('Children') -or $null -eq $Node['Children']) {
        return
    }

    # Unicode constants (avoids character encoding corruption)
    $branch = "$([char]0x251C)$([char]0x2500)$([char]0x2500) " # ├── 
    $corner = "$([char]0x2514)$([char]0x2500)$([char]0x2500) " # └── 
    $vert   = "$([char]0x2502)   "                            # │   

    [System.Collections.IList]$children = $Node['Children']
    $totalItems = $children.Count
    $currentIndex = 0

    foreach ($child in $children) {
        $currentIndex++
        $isLast = ($currentIndex -eq $totalItems)

        $connector   = if ($isLast) { $corner } else { $branch }
        $childIndent = if ($isLast) { '    ' } else { $vert }

        [System.String]$name = if ($child.Contains('Name')) { $child['Name'] } else { 'Node' }
        [System.ConsoleColor]$color = if ($child.Contains('Color')) { $child['Color'] } else { [System.ConsoleColor]::Gray }

        Write-Host "$Indent$connector$name" -ForegroundColor $color

        if ($child.Contains('Children') -and $null -ne $child['Children'] -and $child['Children'].Count -gt 0) {
            showTree -Node $child -Indent "$Indent$childIndent" -CurrentDepth ($CurrentDepth + 1) -MaxDepth $MaxDepth
        }
    }
}