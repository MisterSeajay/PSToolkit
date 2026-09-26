Describe "Get-FolderStructure" {
    BeforeAll {
        $RootFolder = Join-Path -Path $PSScriptRoot -ChildPath ".." | Convert-Path
        Import-Module (Join-Path $RootFolder "PSToolkit.psm1") -Force
    }

    Context "Cmdlet Execution and Aliases" {
        It "Alias 'tree' should map to Get-FolderStructure" {
            $alias = Get-Alias -Name "tree" -ErrorAction SilentlyContinue
            $alias | Should -Not -BeNullOrEmpty
            $alias.Definition | Should -Be "Get-FolderStructure"
        }

        It "Get-FolderStructure executes cleanly against a test directory" {
            { Get-FolderStructure -Path $PSScriptRoot -MaxDepth 1 } | Should -Not -Throw
        }
    }

    Context "Exclude follows the Get-ChildItem -Exclude convention" {
        BeforeAll {
            function New-TestTree {
                $root = Join-Path ([System.IO.Path]::GetTempPath()) ("gfs-" + [System.Guid]::NewGuid().ToString("N"))
                New-Item -ItemType Directory -Path $root -Force | Out-Null
                New-Item -ItemType Directory -Path (Join-Path $root "keep") -Force | Out-Null
                New-Item -ItemType Directory -Path (Join-Path $root "node_modules") -Force | Out-Null
                New-Item -ItemType Directory -Path (Join-Path $root "AppData") -Force | Out-Null
                New-Item -ItemType Directory -Path (Join-Path $root "keep\nested") -Force | Out-Null
                Set-Content -Path (Join-Path $root "rootfile.txt") -Value "x"
                return $root
            }

            function Get-TreeText {
                param([string]$Path, [hashtable]$Splat)
                return ((Get-FolderStructure @Splat -Path $Path 6>&1) | Out-String)
            }
        }

        It "Omits a directory whose name matches exactly" {
            $root = New-TestTree
            try {
                $text = Get-TreeText -Path $root -Splat @{ Exclude = @('node_modules') }
                $text | Should -Not -Match "node_modules"
                $text | Should -Match "keep"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Supports wildcard patterns rather than requiring an exact name" {
            $root = New-TestTree
            try {
                $text = Get-TreeText -Path $root -Splat @{ Exclude = @('*Data*') }
                $text | Should -Not -Match "AppData"
                $text | Should -Match "node_modules"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Prunes a matching directory instead of walking into it" {
            $root = New-TestTree
            try {
                # 'keep\nested' only appears if keep was walked into.
                $text = Get-TreeText -Path $root -Splat @{ Exclude = @('keep') }
                $text | Should -Not -Match "nested"
                $text | Should -Match "AppData"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Applies the same matching rules to files as to directories" {
            $root = New-TestTree
            try {
                $text = Get-TreeText -Path $root -Splat @{ Exclude = @('*.txt') }
                $text | Should -Not -Match "rootfile\.txt"
                $text | Should -Match "node_modules"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}