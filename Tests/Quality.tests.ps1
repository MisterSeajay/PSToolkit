Describe "PSScriptAnalyzer Code Quality" {
    BeforeAll {
        if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
            Set-ItResult -Skipped -Because "PSScriptAnalyzer module is not installed."
        }
        $RootFolder = Join-Path -Path $PSScriptRoot -ChildPath ".." | Convert-Path
    }

    It "All public and private scripts should pass PSScriptAnalyzer without errors" {
        $results = Invoke-ScriptAnalyzer -Path $RootFolder -Recurse -Severity Error
        
        if ($results.Count -gt 0) {
            $errorDetails = $results | ForEach-Object { "$($_.ScriptName):L$($_.Line) [$($_.RuleName)] $($_.Message)" }
            Write-Warning ($errorDetails -join "`n")
        }

        $results.Count | Should -Be 0
    }
}