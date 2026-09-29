<#
.SYNOPSIS
    Converts text to title case, capitalising the first letter of each word.
.DESCRIPTION
    Capitalizes the first letter of each word, where words in the string are
    separated by spaces, hyphens or other non-alphanumeric characters (that is,
    by "word boundary" characters). Letters following an apostrophe within a
    word are un-capitalized, so "o'brien" becomes "O'brien" rather than
    "O'Brien".

    This is title case rather than sentence case: it capitalizes every word, not
    just the first one.
.PARAMETER Text
    The text to convert. Accepts pipeline input.
.EXAMPLE
    ConvertTo-TitleCase -Text "hello-world"
    Returns: Hello-World
.EXAMPLE
    "hello world" | ConvertTo-TitleCase
    Returns: Hello World
.NOTES
    Hyphens are treated as word boundaries and preserved, so a hyphenated
    compound gets both halves capitalised: "well-known" becomes "Well-Known".
.LINK
    https://github.com/MisterSeajay/PSToolkit
#>
function ConvertTo-TitleCase {
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   Position=0,
                   HelpMessage="Text string to capitalize")]
        [string]
        $Text
    )

    begin {
        Set-StrictMode -Version 2
    }
    
    process {
        Write-Debug "Capitalizing $Text"

        # Capitalize all letters following a word boundary
        $CapitalizedWords = [Regex]::Replace($Text, '\b\w', { param($string) $string.Value.ToUpper() })

        # Fix capitalization of letters following apostrophes within words
        $CapitalizedWords = [Regex]::Replace($CapitalizedWords, '\w''\w', {
            param($string)
            $string.Value.Substring(0, 2) + $string.Value.Substring(2, 1).ToLower()
        })

        return $CapitalizedWords
    }

    end { }  # Nothing to finalise: all of this command's work is per-item.
}
