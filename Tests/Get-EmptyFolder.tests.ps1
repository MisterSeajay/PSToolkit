Describe "Get-EmptyFolder" {
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
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("gef-" + [System.Guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root "empty-one") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root "empty-two") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root "node_modules") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root "AppData") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root "notempty") -Force | Out-Null
            Set-Content -Path (Join-Path $root "notempty\file.txt") -Value "x"
            return $root
        }
    }

    AfterAll {
        Get-Module PSToolkit | Remove-Module -Force -ErrorAction SilentlyContinue
    }

    Context "Empty folder detection" {
        It "Returns a DirectoryInfo for each empty directory" {
            $root = New-TestTree
            try {
                $result = @(Get-EmptyFolder -Path $root)
                $names = @($result | ForEach-Object { $_.Name })
                $names | Should -Contain "empty-one"
                $names | Should -Contain "empty-two"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Does not report directories that contain a file" {
            $root = New-TestTree
            try {
                $names = @(Get-EmptyFolder -Path $root | ForEach-Object { $_.Name })
                $names | Should -Not -Contain "notempty"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Returns DirectoryInfo objects so results can be piped onward" {
            $root = New-TestTree
            try {
                @(Get-EmptyFolder -Path $root) | Should -BeOfType [System.IO.DirectoryInfo]
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Exclude follows the Get-ChildItem -Exclude convention" {
        It "Accepts multiple patterns and omits matching names" {
            $root = New-TestTree
            try {
                $names = @(Get-EmptyFolder -Path $root -Exclude 'empty-one', 'empty-two' | ForEach-Object { $_.Name })
                $names | Should -Not -Contain "empty-one"
                $names | Should -Not -Contain "empty-two"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Supports wildcard patterns rather than requiring an exact name" {
            $root = New-TestTree
            try {
                $names = @(Get-EmptyFolder -Path $root -Exclude 'empty-*' | ForEach-Object { $_.Name })
                $names | Should -Not -Contain "empty-one"
                $names | Should -Not -Contain "empty-two"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Matches against the directory name, not the full path" {
            $root = New-TestTree
            try {
                # 'node_modules' is a name, so it matches. A path-shaped pattern
                # containing directory separators must not be required.
                $names = @(Get-EmptyFolder -Path $root -Exclude 'node_modules' | ForEach-Object { $_.Name })
                $names | Should -Not -Contain "node_modules"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Excludes nothing when no pattern is supplied" {
            $root = New-TestTree
            try {
                @(Get-EmptyFolder -Path $root | ForEach-Object { $_.Name }) | Should -Contain "empty-one"
            }
            finally {
                Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
