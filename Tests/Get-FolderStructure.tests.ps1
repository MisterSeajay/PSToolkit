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
}