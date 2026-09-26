Describe "Get-FolderStructure" {
    BeforeAll {
        $RootFolder = Join-Path -Path $PSScriptRoot -ChildPath ".." | Convert-Path
        Import-Module (Join-Path $RootFolder "PSToolkit.psm1") -Force

        # A disposable fixture under the temp path. Suppressed rather than renamed:
        # creating throwaway test data is not a state change that needs -WhatIf.
        # The suppression uses the positional category argument; the named
        # Justification form throws "no overload for .ctor" when placed here.
        function New-TestTree {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '')]
            param()
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("gfs-" + [System.Guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root "keep") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root "node_modules") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root "keep\nested") -Force | Out-Null
            Set-Content -Path (Join-Path $root "rootfile.txt") -Value "x"
            Set-Content -Path (Join-Path $root "keep\inner.txt") -Value "x"
            return $root
        }
    }

    AfterAll {
        Get-Module PSToolkit | Remove-Module -Force -ErrorAction SilentlyContinue
    }

    Context "Output shape" {
        It "Emits the root directory at depth 0" {
            $root = New-TestTree
            try {
                $first = @(Get-FolderStructure -Path $root)[0]
                $first.Name | Should -Be (Split-Path -Leaf $root)
                $first.Depth | Should -Be 0
                $first.PSIsContainer | Should -BeTrue
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Returns objects to the pipeline, not host output" {
            $root = New-TestTree
            try {
                # The whole point of the refactor: this must be capturable, countable
                # and filterable without capturing the information stream.
                $nodes = @(Get-FolderStructure -Path $root)
                $nodes.Count | Should -BeGreaterThan 1
                $nodes[0] | Should -BeOfType [PSCustomObject]
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Exposes Name, FullName, Depth and PSIsContainer" {
            $root = New-TestTree
            try {
                # Assert on one node directly. Collecting the property names through
                # ForEach-Object would unroll the inner array into separate strings.
                $node = @(Get-FolderStructure -Path $root)[0]
                $node.PSObject.Properties.Name | Should -Contain 'Name'
                $node.PSObject.Properties.Name | Should -Contain 'FullName'
                $node.PSObject.Properties.Name | Should -Contain 'Depth'
                $node.PSObject.Properties.Name | Should -Contain 'PSIsContainer'
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Records a correct depth for each level" {
            $root = New-TestTree
            try {
                $nodes = @(Get-FolderStructure -Path $root)
                ($nodes | Where-Object { $_.Name -eq 'keep' }).Depth | Should -Be 1
                ($nodes | Where-Object { $_.Name -eq 'nested' }).Depth | Should -Be 2
                ($nodes | Where-Object { $_.Name -eq 'inner.txt' }).Depth | Should -Be 2
                ($nodes | Where-Object { $_.Name -eq 'rootfile.txt' }).Depth | Should -Be 1
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Does not decorate directory names with a trailing separator" {
            $root = New-TestTree
            try {
                $dir = @(Get-FolderStructure -Path $root)[0]
                $dir.Name | Should -Not -Match '/$'
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Emits directories before files, each group sorted by name" {
            $root = New-TestTree
            try {
                $children = @(Get-FolderStructure -Path $root | Select-Object -Skip 1)
                $names = @($children | ForEach-Object { $_.Name })
                $containerIndexes = @()
                for ($i = 0; $i -lt $children.Count; $i++) {
                    if ($children[$i].PSIsContainer) { $containerIndexes += $i }
                }
                $containerIndexes | Should -Not -BeNullOrEmpty
                ($containerIndexes | Measure-Object -Maximum).Maximum | Should -Be ($containerIndexes.Count - 1)
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Filtering with the pipeline" {
        It "Can be filtered by depth" {
            $root = New-TestTree
            try {
                $topLevel = @(Get-FolderStructure -Path $root | Where-Object { $_.Depth -eq 1 })
                $topLevel.Count | Should -BeGreaterThan 0
                $topLevel | ForEach-Object { $_.Depth | Should -Be 1 }
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Can be filtered to containers only" {
            $root = New-TestTree
            try {
                $files = @(Get-FolderStructure -Path $root | Where-Object { -not $_.PSIsContainer })
                $files.Count | Should -BeGreaterThan 0
                $files | ForEach-Object { $_.PSIsContainer | Should -BeFalse }
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Parameters" {
        It "Emits only the root at -MaxDepth 1" {
            $root = New-TestTree
            try {
                @(Get-FolderStructure -Path $root -MaxDepth 1).Count | Should -Be 1
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Stops descending at the requested depth" {
            $root = New-TestTree
            try {
                $names = @(Get-FolderStructure -Path $root -MaxDepth 2 | ForEach-Object { $_.Name })
                $names | Should -Contain "keep"
                $names | Should -Not -Contain "nested"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Omits files with -Directory" {
            $root = New-TestTree
            try {
                $nodes = @(Get-FolderStructure -Path $root -Directory)
                $nodes | ForEach-Object { $_.PSIsContainer | Should -BeTrue }
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Omits directories with -File" {
            $root = New-TestTree
            try {
                $nodes = @(Get-FolderStructure -Path $root -File)
                # The root is always emitted so the tree has an anchor, matching the
                # previous renderer. Everything below it is a file.
                $nodes[0].PSIsContainer | Should -BeTrue
                $nodes[0].Depth | Should -Be 0
                $belowRoot = @($nodes | Select-Object -Skip 1)
                $belowRoot.Count | Should -BeGreaterThan 0
                $belowRoot | ForEach-Object { $_.PSIsContainer | Should -BeFalse }
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Prunes a directory matching -Exclude" {
            $root = New-TestTree
            try {
                $names = @(Get-FolderStructure -Path $root -Exclude 'node_modules' | ForEach-Object { $_.Name })
                $names | Should -Not -Contain "node_modules"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Supports wildcard -Exclude patterns" {
            $root = New-TestTree
            try {
                $names = @(Get-FolderStructure -Path $root -Exclude '*.txt' | ForEach-Object { $_.Name })
                $names | Should -Not -Contain "rootfile.txt"
                $names | Should -Not -Contain "inner.txt"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Accepts several -Exclude patterns" {
            $root = New-TestTree
            try {
                $names = @(Get-FolderStructure -Path $root -Exclude 'node_modules', '*.txt' | ForEach-Object { $_.Name })
                $names | Should -Not -Contain "node_modules"
                $names | Should -Not -Contain "rootfile.txt"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Errors when the path is not a directory" {
            $root = New-TestTree
            try {
                $file = Join-Path $root "rootfile.txt"
                { Get-FolderStructure -Path $file -ErrorAction Stop } | Should -Throw
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Cmdlet Execution and Aliases" {
        It "Alias 'tree' should map to Format-Tree" {
            $alias = Get-Alias -Name "tree" -ErrorAction SilentlyContinue
            $alias | Should -Not -BeNullOrEmpty
            $alias.Definition | Should -Be "Format-Tree"
        }
    }
}
