Describe "Format-Tree" {
    BeforeAll {
        $RootFolder = Join-Path -Path $PSScriptRoot -ChildPath ".." | Convert-Path
        Import-Module (Join-Path $RootFolder "PSToolkit.psm1") -Force

        # Box-drawing glyphs are built from [char] codes in the assertions too, so a
        # failure message stays readable whatever the console encoding, and so a
        # decoding problem cannot masquerade as a rendering difference.
        $script:Branch  = "$([char]0x251C)$([char]0x2500)$([char]0x2500) "
        $script:Last    = "$([char]0x2514)$([char]0x2500)$([char]0x2500) "
        $script:Vertical = "$([char]0x2502)   "
        $script:Blank   = '    '

        # A pure in-memory factory. The 'New' verb trips the ShouldProcess rule even
        # though nothing on the system is changed.
        function New-Node {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '')]
            param([string]$Name, [int]$Depth, [bool]$IsContainer = $true)
            [PSCustomObject]@{
                Name          = $Name
                FullName      = $Name
                Depth         = $Depth
                PSIsContainer = $IsContainer
            }
        }

        function Get-RenderedLines {
            param([object[]]$Nodes)
            # The comma operator is deliberate: a plain return @() unrolls a
            # single-element array into a bare string, and the caller would then be
            # indexing a character rather than a line.
            return , @($Nodes | Format-Tree 6>&1 | ForEach-Object { [string]$_ })
        }

        # A disposable fixture under the temp path. Suppressed rather than renamed:
        # creating throwaway test data is not a state change that needs -WhatIf.
        # The suppression uses the positional category argument; the named
        # Justification form throws "no overload for .ctor" when placed here.
        function New-TestTree {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '')]
            param()
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("ft-" + [System.Guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path (Join-Path $root "alpha") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root "beta") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root "alpha\deep") -Force | Out-Null
            Set-Content -Path (Join-Path $root "one.txt") -Value "x"
            Set-Content -Path (Join-Path $root "two.txt") -Value "x"
            return $root
        }
    }

    AfterAll {
        Get-Module PSToolkit | Remove-Module -Force -ErrorAction SilentlyContinue
    }

    Context "Rendering from pipeline input" {
        It "Draws a root with no connector" {
            $lines = Get-RenderedLines -Nodes @(New-Node -Name 'root' -Depth 0)
            $lines.Count | Should -Be 1
            $lines[0] | Should -Be 'root/'
        }

        It "Uses a branch connector for a non-final sibling and a last connector for the final one" {
            $nodes = @(
                New-Node -Name 'root' -Depth 0
                New-Node -Name 'a' -Depth 1
                New-Node -Name 'b' -Depth 1
            )
            $lines = Get-RenderedLines -Nodes $nodes
            $lines[1] | Should -Be "$($script:Branch)a/"
            $lines[2] | Should -Be "$($script:Last)b/"
        }

        It "Appends a separator to containers but not to files" {
            $nodes = @(
                New-Node -Name 'root' -Depth 0
                New-Node -Name 'f' -Depth 1 -IsContainer $false
            )
            $lines = Get-RenderedLines -Nodes $nodes
            $lines[1] | Should -Be "$($script:Last)f"
        }

        It "Marks a directory that has children as a non-final sibling" {
            # The regression case: 'a' has a child, so the node after it is that
            # child rather than a sibling. 'a' is still not the last of its group.
            $nodes = @(
                New-Node -Name 'root' -Depth 0
                New-Node -Name 'a' -Depth 1
                New-Node -Name 'a1' -Depth 2
                New-Node -Name 'b' -Depth 1
            )
            $lines = Get-RenderedLines -Nodes $nodes
            $lines[1] | Should -Be "$($script:Branch)a/"
            $lines[2] | Should -Be "$($script:Vertical)$($script:Last)a1/"
        }

        It "Indents the last top-level branch with blanks rather than a vertical bar" {
            $nodes = @(
                New-Node -Name 'root' -Depth 0
                New-Node -Name 'a' -Depth 1
                New-Node -Name 'a1' -Depth 2
                New-Node -Name 'b' -Depth 1
                New-Node -Name 'b1' -Depth 2
            )
            $lines = Get-RenderedLines -Nodes $nodes
            $lines[3] | Should -Be "$($script:Last)b/"
            $lines[4] | Should -Be "$($script:Blank)$($script:Last)b1/"
        }

        It "Falls back to the current location when given no input" {
            # A bare Format-Tree has to draw something: the 'tree' alias is only
            # worth having if `tree` on its own replaces the command it borrows
            # its name from. This replaces an earlier expectation of no output,
            # which was the reason bare `tree` printed nothing at all.
            $root = New-TestTree
            $here = Get-Location
            try {
                Push-Location -Path $root
                $lines = @((Format-Tree 6>&1) | ForEach-Object { [string]$_ })
                Pop-Location
                $lines.Count | Should -BeGreaterThan 1
                # Built into a variable first: inline, `Should -Be (expr) + '/'`
                # lets PowerShell hand the '+' to Pester as a -Because reason.
                $expectedRoot = (Split-Path -Path $root -Leaf) + '/'
                $lines[0] | Should -Be $expectedRoot
            }
            finally {
                Set-Location -Path $here
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Rendering from -Path" {
        It "Produces the same shape as the pipeline form" {
            $root = New-TestTree
            try {
                $viaPath     = @((Format-Tree -Path $root 6>&1) | ForEach-Object { [string]$_ })
                $viaPipeline = Get-RenderedLines -Nodes @(Get-FolderStructure -Path $root)
                ($viaPath -join "`n") | Should -Be ($viaPipeline -join "`n")
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Forwards -Exclude to Get-FolderStructure" {
            $root = New-TestTree
            try {
                $text = ((Format-Tree -Path $root -Exclude 'alpha' 6>&1) | Out-String)
                $text | Should -Not -Match "alpha"
                $text | Should -Match "beta"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Forwards -Directory to Get-FolderStructure" {
            $root = New-TestTree
            try {
                $text = ((Format-Tree -Path $root -Directory 6>&1) | Out-String)
                $text | Should -Not -Match "one\.txt"
                $text | Should -Match "alpha"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Forwards -MaxDepth to Get-FolderStructure" {
            $root = New-TestTree
            try {
                $lines = @((Format-Tree -Path $root -MaxDepth 1 6>&1) | ForEach-Object { [string]$_ })
                $lines.Count | Should -Be 1
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "The tree alias" {
        It "Draws a tree when invoked with no pipeline input" {
            $root = New-TestTree
            try {
                $viaAlias = @((tree -Path $root 6>&1) | ForEach-Object { [string]$_ })
                $viaFunction = @((Format-Tree -Path $root 6>&1) | ForEach-Object { [string]$_ })
                $viaAlias.Count | Should -BeGreaterThan 1
                ($viaAlias -join "`n") | Should -Be ($viaFunction -join "`n")
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Draws the current location when given no arguments at all" {
            # The cmd.exe-compatibility case, and the one the alias exists for.
            # Regression test: with no default for -Path this produced no output.
            $root = New-TestTree
            $here = Get-Location
            try {
                Push-Location -Path $root
                $bare = @((tree 6>&1) | ForEach-Object { [string]$_ })
                $viaPath = @((Format-Tree -Path $root 6>&1) | ForEach-Object { [string]$_ })
                Pop-Location
                $bare.Count | Should -BeGreaterThan 1
                ($bare -join "`n") | Should -Be ($viaPath -join "`n")
            }
            finally {
                Set-Location -Path $here
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Output discipline" {
        It "Writes nothing to the success stream" {
            $root = New-TestTree
            try {
                $stray = @((Get-FolderStructure -Path $root | Format-Tree) |
                    Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })
                $stray.Count | Should -Be 0
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
