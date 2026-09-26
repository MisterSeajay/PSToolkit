Describe "PSToolkit Module Infrastructure" {
    BeforeAll {
        $RootFolder = Join-Path -Path $PSScriptRoot -ChildPath ".." | Convert-Path
        $ManifestPath = Join-Path -Path $RootFolder -ChildPath "PSToolkit.psd1"
        $ModulePath   = Join-Path -Path $RootFolder -ChildPath "PSToolkit.psm1"
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