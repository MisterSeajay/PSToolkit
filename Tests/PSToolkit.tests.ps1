Describe "PSToolkit Module Infrastructure" {
    BeforeAll {
        $RootFolder = Join-Path -Path $PSScriptRoot -ChildPath ".." | Convert-Path
        $ManifestPath = Join-Path -Path $RootFolder -ChildPath "PSToolkit.psd1"
        $ModulePath   = Join-Path -Path $RootFolder -ChildPath "PSToolkit.psm1"
    }

    Context "Comment-Based Help" {
        # The README points users at Get-Help for per-command detail, so that help has
        # to exist and stay complete. These tests are what make that promise real.
        BeforeAll {
            $PublicFolder = Join-Path -Path $RootFolder -ChildPath "Public"

            # Parameters deliberately left undocumented. Get-FolderStructure.LegacyArgs
            # is a ValueFromRemainingArguments shim that swallows cmd.exe-style /A and
            # /F flags from the old tree command. It is not a real option, so
            # documenting it would advertise a dead calling convention.
            $UndocumentedByDesign = @{
                'Get-FolderStructure' = @('LegacyArgs')
            }

            $CommonParameters = @(
                'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction',
                'ProgressAction', 'ErrorVariable', 'WarningVariable',
                'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable'
            )
        }

        It "Every public function should have complete comment-based help" {
            $problems = [System.Collections.Generic.List[string]]::new()

            $files = Get-ChildItem -Path $PublicFolder -Filter "*.ps1"
            $files | Should -Not -BeNullOrEmpty -Because "the Public folder should contain exported functions"

            foreach ($file in $files) {
                $tokens = $null
                $parseErrors = $null
                $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                    $file.FullName, [ref]$tokens, [ref]$parseErrors)

                if (@($parseErrors).Count -gt 0) {
                    $problems.Add("$($file.Name): $($parseErrors.Count) parse error(s)")
                    continue
                }

                $functions = @($ast.FindAll(
                    { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] },
                    $true))
                if ($functions.Count -eq 0) {
                    $problems.Add("$($file.Name): no function definition found")
                    continue
                }

                $name = $functions[0].Name

                # GetHelpContent() must be called on the FunctionDefinitionAst; on the
                # file-level ScriptBlockAst it silently returns nothing.
                $help = $functions[0].GetHelpContent()

                if (-not $help) {
                    $problems.Add("$name ($($file.Name)): no comment-based help block")
                    continue
                }

                if ([string]::IsNullOrWhiteSpace($help.Synopsis)) {
                    $problems.Add("$name ($($file.Name)): missing or empty .SYNOPSIS")
                }
                if ([string]::IsNullOrWhiteSpace($help.Description)) {
                    $problems.Add("$name ($($file.Name)): missing or empty .DESCRIPTION")
                }
                if (@($help.Examples.Example).Count -eq 0) {
                    $problems.Add("$name ($($file.Name)): no .EXAMPLE")
                }

                # Parameters is a Dictionary[String,String], so the documented names are
                # its Keys. The parser upper-cases them, hence the invariant keys.
                $descriptions = @{}
                foreach ($key in $help.Parameters.Keys) {
                    $descriptions[$key.ToUpperInvariant()] = $help.Parameters[$key]
                }
                $documented = @($descriptions.Keys)

                $declared = @()
                if ($functions[0].Body.ParamBlock) {
                    $declared = @($functions[0].Body.ParamBlock.Parameters |
                        ForEach-Object { $_.Name.VariablePath.UserPath })
                }

                $allowed = @()
                if ($UndocumentedByDesign.ContainsKey($name)) {
                    $allowed = $UndocumentedByDesign[$name]
                }

                foreach ($paramName in ($declared | Where-Object { $CommonParameters -notcontains $_ })) {
                    if ($allowed -contains $paramName) { continue }

                    if ($documented -notcontains $paramName) {
                        $problems.Add("$name ($($file.Name)): parameter '$paramName' has no .PARAMETER entry")
                    }
                    elseif ([string]::IsNullOrWhiteSpace($descriptions[$paramName.ToUpperInvariant()])) {
                        $problems.Add("$name ($($file.Name)): .PARAMETER '$paramName' has an empty description")
                    }
                }

                # Catches a .PARAMETER left behind after a parameter is renamed or removed.
                foreach ($paramName in $documented) {
                    if ($declared -notcontains $paramName) {
                        $problems.Add("$name ($($file.Name)): .PARAMETER '$paramName' matches no declared parameter")
                    }
                }
            }

            ($problems -join [Environment]::NewLine) | Should -BeNullOrEmpty
        }
    }

    Context "Manifest and Module Structure" {
        It "Manifest PSToolkit.psd1 should exist and be valid" {
            Test-Path -Path $ManifestPath | Should -Be $true
            { Test-ModuleManifest -Path $ManifestPath } | Should -Not -Throw
        }

        It "Module PSToolkit.psm1 should import without throwing errors" {
            { Import-Module -Name $ModulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }

        It "Exported functions should all follow Verb-Noun naming" {
            $PublicFolder = Join-Path $RootFolder "Public"
            if (Test-Path $PublicFolder) {
                $PublicFiles = Get-ChildItem -Path $PublicFolder -Filter "*.ps1"
                foreach ($file in $PublicFiles) {
                    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
                    $funcs = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
                    foreach ($func in $funcs) {
                        $func.Name | Should -Match '^[A-Z][a-zA-Z]+-[A-Z][a-zA-Z]+$'
                    }
                }
            }
        }

        It "Functions taking pipeline input should use begin, process and end" {
            # AGENTS.md 1.2. The failure this guards is invisible to a test that only
            # runs the function: a function body with no sections executes once for the
            # whole pipeline rather than once per object, which still produces correct
            # output for a single item and silently keeps only the last item for many.
            #
            # Reading the AST rather than the source text, so a block written on one
            # line is not mistaken for a missing one. An empty 'end { }' counts: the
            # rule is about explicit structure, not about having work to do there.
            $problems = [System.Collections.Generic.List[string]]::new()
            $PublicFolder = Join-Path $RootFolder "Public"

            foreach ($file in (Get-ChildItem -Path $PublicFolder -Filter "*.ps1")) {
                $parseErrors = $null
                $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$parseErrors)
                $funcs = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

                foreach ($func in $funcs) {
                    $takesPipeline = $false
                    if ($func.Body.ParamBlock) {
                        foreach ($param in $func.Body.ParamBlock.Parameters) {
                            foreach ($attr in $param.Attributes) {
                                # [Parameter(...)] is an AttributeAst whose TypeName is
                                # 'Parameter'. There is no ParameterAttributeAst type in
                                # Windows PowerShell 5.1 - naming one makes the test fail
                                # on every input rather than on the thing it checks.
                                if ($attr -isnot [System.Management.Automation.Language.AttributeAst]) { continue }
                                if ($attr.TypeName.Name -ne 'Parameter') { continue }
                                foreach ($named in $attr.NamedArguments) {
                                    if ($named.ArgumentName -notin 'ValueFromPipeline', 'ValueFromPipelineByPropertyName') { continue }
                                    # An attribute value of $true is a VariableExpressionAst,
                                    # so compare on the name rather than evaluating it.
                                    $isTrue = $named.Argument -is [System.Management.Automation.Language.VariableExpressionAst] -and
                                              $named.Argument.VariablePath.UserPath -eq 'true'
                                    if ($isTrue) { $takesPipeline = $true }
                                }
                            }
                        }
                    }
                    if (-not $takesPipeline) { continue }

                    $missing = [System.Collections.Generic.List[string]]::new()
                    if (-not $func.Body.BeginBlock)   { $missing.Add('begin') }
                    if (-not $func.Body.ProcessBlock) { $missing.Add('process') }
                    if (-not $func.Body.EndBlock)     { $missing.Add('end') }

                    if ($missing.Count) {
                        $problems.Add("$($file.Name): $($func.Name) takes pipeline input but has no $($missing -join ', ') block(s)")
                    }
                }
            }

            ($problems -join [Environment]::NewLine) | Should -BeNullOrEmpty
        }
    }

    Context "Test runner exit codes" {
        # A test runner communicates through its exit code. A caller that checks
        # $LASTEXITCODE, or a CI job, cannot see anything written to the error
        # stream, so a runner that reports a problem and then exits 0 is
        # indistinguishable from one that passed.
        #
        # These tests exist because that failure is invisible. A gate that never
        # fails is green forever, and every commit that relies on it looks fine.
        BeforeAll {
            $RunnerPath = Join-Path $RootFolder "Scripts\Invoke-Pester.ps1"

            # The current PowerShell executable, so the child runs the same engine.
            $PowerShellExe = (Get-Process -Id $PID).Path

            # Builds a throwaway module root containing the real runner and a Tests
            # folder holding the supplied test body, then runs the runner over it.
            # The runner derives its root from its own location, so relocating it is
            # what points it at a different suite; no test-only parameter is needed.
            #
            # Supplying -ModulePath routes the run through a harness that replaces
            # PSModulePath first, which is the only way tested here to make Pester
            # genuinely undiscoverable.
            function Invoke-RunnerInSandbox {
                param(
                    [string]$TestBody,
                    [string]$ModulePath
                )

                $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("pstk-runner-" + [guid]::NewGuid().ToString('N'))
                $scripts = Join-Path $sandbox "Scripts"
                $tests = Join-Path $sandbox "Tests"
                New-Item -ItemType Directory -Path $scripts, $tests -Force | Out-Null
                Copy-Item -Path $RunnerPath -Destination $scripts -Force
                Set-Content -Path (Join-Path $tests "sandbox.tests.ps1") -Value $TestBody

                try {
                    $runner = Join-Path $scripts "Invoke-Pester.ps1"
                    $entry = $runner

                    if ($ModulePath) {
                        # A harness file rather than -Command: a double quote inside a
                        # string handed to a native exe is consumed by the argument
                        # parser, and setting PSModulePath to '' through -Command hangs
                        # the child. -File with a real script avoids both.
                        #
                        # Assembled by concatenation rather than as a here-string: a
                        # here-string terminator must start at column 0, which cannot be
                        # done legibly inside a nested function.
                        $nl = [Environment]::NewLine
                        $q = [char]39
                        $harness = '$env:PSModulePath = ' + $q + $ModulePath + $q + $nl +
                                   '& ' + $q + $runner + $q + $nl +
                                   'exit $LASTEXITCODE'
                        $entry = Join-Path $sandbox "harness.ps1"
                        Set-Content -Path $entry -Value $harness
                    }

                    $output = & $PowerShellExe -NoProfile -File $entry 2>&1
                    # Read immediately: nothing may run between the native call and this.
                    $code = $LASTEXITCODE
                    return [PSCustomObject]@{ ExitCode = $code; Output = ($output | Out-String) }
                }
                finally {
                    Remove-Item -Path $sandbox -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It "Should exit zero when every test passes" {
            $run = Invoke-RunnerInSandbox "Describe 'Deliberately passing' { It 'passes' { 1 | Should -Be 1 } }"
            $run.ExitCode | Should -Be 0
            $run.Output | Should -Match 'tests passed'
        }

        It "Should exit non-zero when a test fails" {
            # The central case. If this passes, the gate detects a real failure.
            $run = Invoke-RunnerInSandbox "Describe 'Deliberately failing' { It 'fails' { 1 | Should -Be 2 } }"
            $run.ExitCode | Should -Not -Be 0
        }

        It "Should not claim success when a test fails" {
            $run = Invoke-RunnerInSandbox "Describe 'Deliberately failing' { It 'fails' { 1 | Should -Be 2 } }"
            $run.Output | Should -Not -Match 'All \d+ tests passed'
            $run.Output | Should -Match 'Test run failed'
        }

        It "Should exit non-zero when a test file cannot be parsed" {
            # A file that fails to parse produces a failed container, not a failed
            # test, so it is reported through FailedContainersCount. Counting only
            # FailedCount would read this as a clean run with zero tests.
            $run = Invoke-RunnerInSandbox "Describe 'Unclosed' {"
            $run.ExitCode | Should -Not -Be 0
        }

        It "Should exit non-zero when Pester is unavailable" {
            Test-Path -Path $RunnerPath | Should -Be $true

            # A module path that contains no modules, not an empty PSModulePath.
            # PowerShell reads an empty PSModulePath as "use the defaults" and
            # finds Pester anyway, so that variant reaches the full suite instead
            # of the branch under test and would pass for the wrong reason.
            $run = Invoke-RunnerInSandbox `
                        -TestBody "Describe 'Deliberately passing' { It 'passes' { 1 | Should -Be 1 } }" `
                        -ModulePath "C:\pstk-no-such-module-path"

            $run.ExitCode | Should -Not -Be 0 -Because "a skipped test run is not a pass"
            $run.Output | Should -Match 'unverified' -Because "the failure should say the run proved nothing"
        }
    }
}
