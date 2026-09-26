<#
.SYNOPSIS
    Tests whether an item name matches any of a set of wildcard patterns.
.DESCRIPTION
    Applies wildcard matching to a single item name, following the same
    convention as Get-ChildItem -Exclude: patterns are tested against the item
    name rather than its full path.

    Returns as soon as any pattern matches, so callers can prune a directory
    before descending into it. An absent or empty pattern set excludes nothing.
.PARAMETER Name
    The item name to test, meaning the leaf name with no directory portion.
.PARAMETER Pattern
    One or more wildcard patterns, for example '*.tmp' or 'node_modules'.
.EXAMPLE
    testNameExcluded -Name 'node_modules' -Pattern '.git', 'node_modules'
    Returns $true, because the name matches the second pattern exactly.
.EXAMPLE
    testNameExcluded -Name 'node_modules' -Pattern '*modules*'
    Returns $true, because the name matches the wildcard pattern.
.EXAMPLE
    testNameExcluded -Name 'src' -Pattern '*.txt', '*.log'
    Returns $false, because neither pattern matches the name.
.NOTES
    Matching follows Get-ChildItem -Exclude semantics and is case-insensitive.
.LINK
    https://github.com/MisterSeajay/PSToolkit
#>
function testNameExcluded {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$Name,

        [Parameter(Position = 1)]
        [System.String[]]$Pattern
    )

    if ([string]::IsNullOrWhiteSpace($Name) -or $null -eq $Pattern) {
        return $false
    }

    foreach ($candidate in $Pattern) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and $Name -like $candidate) {
            return $true
        }
    }

    return $false
}
