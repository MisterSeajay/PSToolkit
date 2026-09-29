Describe "PSScriptAnalyzer Code Quality" {
    BeforeAll {
        $RootFolder = Join-Path -Path $PSScriptRoot -ChildPath ".." | Convert-Path

        # The two folders that are actually shipped to a user. Tests/ and Scripts/ are
        # not part of the module, and a warning in a developer utility is not a
        # warning in the code someone installs.
        $ShippedFolders = @(
            (Join-Path $RootFolder 'Public')
            (Join-Path $RootFolder 'Private')
        )

        # Deliberate exceptions to the Warning gate over shipped module code. Each
        # entry is "<file>:<rule>" and must be explained. An unexplained allowlist
        # entry is a suppressed defect wearing a comment, so an empty list is the
        # healthy state and adding to it should be argued for, not expedient.
        $WarningAllowList = @(
            # (none)
        )

        $Analyzer = Get-Module -ListAvailable -Name PSScriptAnalyzer
        if (-not $Analyzer) {
            # Loudly, and not as a silent skip. A run that linted nothing is
            # indistinguishable in the output from a run that linted everything,
            # and reading "0 errors" off the second is exactly the mistake this
            # repo has already made once with a test runner.
            Write-Warning @'
PSScriptAnalyzer is NOT installed, so no code was linted and this gate is
unverified. Install it with:
    Install-Module PSScriptAnalyzer -Scope CurrentUser
'@
        }
    }

    It "Should report no PSScriptAnalyzer errors anywhere in the repository" {
        if (-not $Analyzer) {
            Write-Warning 'Skipped, unverified: PSScriptAnalyzer is not installed.'
            return
        }

        $results = Invoke-ScriptAnalyzer -Path $RootFolder -Recurse -Severity Error

        if ($results.Count -gt 0) {
            $details = $results | ForEach-Object { "$($_.ScriptName):L$($_.Line) [$($_.RuleName)] $($_.Message)" }
            Write-Warning ($details -join "`n")
        }

        $results.Count | Should -Be 0
    }

    It "Should report no PSScriptAnalyzer warnings in the shipped module code" {
        # The stricter gate. It applies only to what a user actually installs,
        # because holding the whole repository to Warning would mean fixing
        # Pester's own BeforeAll false positives and a developer's shell
        # profile in order to keep the module honest.
        if (-not $Analyzer) {
            Write-Warning 'Skipped, unverified: PSScriptAnalyzer is not installed.'
            return
        }

        # One call per folder: Invoke-ScriptAnalyzer's -Path is a [string], so
        # passing the array binds nothing useful and fails to convert.
        $results = foreach ($folder in $ShippedFolders) {
            Invoke-ScriptAnalyzer -Path $folder -Recurse -Severity Warning
        }

        $unexplained = $results | Where-Object {
            $key = "$(Split-Path $_.ScriptName -Leaf):$($_.RuleName)"
            $key -notin $WarningAllowList
        }

        if ($unexplained.Count -gt 0) {
            $details = $unexplained | ForEach-Object {
                "$($_.ScriptName):L$($_.Line) [$($_.RuleName)] $($_.Message)"
            }
            Write-Warning ($details -join "`n")
        }

        # Asserted empty rather than counted, so one run reports every offender
        # instead of one per run. Comparing to a count would also pass if a
        # warning were traded for a different one.
        ($unexplained | ForEach-Object { "$($_.ScriptName):L$($_.Line) [$($_.RuleName)]" }) -join "`n" |
            Should -BeNullOrEmpty
    }
}
