function Parse-IniFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [string]
        $Path
    )

    Write-Verbose "parseIniFile: Reading $Path"

    Get-Content $Path | Select-String -SimpleMatch "=" | Foreach-Object {
        $Name = ($_ -split('='))[0]
        $Value = ($_ -split('='))[1]
        Write-Debug "$Name = $Value"
        New-Variable -Scope Script -Name $Name -Value $Value -WhatIf:$false
    }
}
