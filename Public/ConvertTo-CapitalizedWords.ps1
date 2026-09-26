<#
.SYNOPSIS
    Capitalizes initial letters of words in a text string.
.DESCRIPTION
    Capitalizes initial letters of words, where words in the string
    can be separated by spaces, hyphens or other non-alphanumeric
    characters (i.e. "word boundary" characters). The function tries
    to un-capitalize letters following apostrophes within words.
.PARAMETER Text
    The input text string to be capitalized.
.EXAMPLE
    ConvertTo-CapitalizedWords -Text "hello-world"
    Returns: Hello-World
.EXAMPLE
    "hello world" | ConvertTo-CapitalizedWords
    Returns: Hello World
.NOTES
    Author: MisterSeajay
.LINK
    https://github.com/MisterSeajay/PSToolkit
#>
function ConvertTo-CapitalizedWords {
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
}