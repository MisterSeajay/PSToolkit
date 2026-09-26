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
    }
}