Describe "Get-FolderSize" {
    BeforeAll {
        $RootFolder = Join-Path -Path $PSScriptRoot -ChildPath ".." | Convert-Path
        Import-Module (Join-Path $RootFolder "PSToolkit.psm1") -Force

        $TempDir = [System.IO.Path]::GetTempPath()
        $TestRoot = Join-Path -Path $TempDir -ChildPath "PSToolkit_FolderSize_Tests"
        if (Test-Path $TestRoot) { Remove-Item $TestRoot -Recurse -Force }
        
        $SubFolderA = New-Item -Path (Join-Path $TestRoot "FolderA") -ItemType Directory -Force
        $SubFolderB = New-Item -Path (Join-Path $TestRoot "FolderB") -ItemType Directory -Force

        $fileA = Join-Path $SubFolderA.FullName "test1.dat"
        $fileB = Join-Path $SubFolderB.FullName "test2.dat"
        
        # Write 1MB to FolderA
        [byte[]]$buffer1MB = [byte[]]::new(1MB)
        [System.IO.File]::WriteAllBytes($fileA, $buffer1MB)

        # Write 2MB to FolderB
        [byte[]]$buffer2MB = [byte[]]::new(2MB)
        [System.IO.File]::WriteAllBytes($fileB, $buffer2MB)
    }

    AfterAll {
        if (Test-Path $TestRoot) { Remove-Item $TestRoot -Recurse -Force }
    }

    It "Returns custom objects with expected properties" {
        $results = Get-FolderSize -Path $TestRoot
        $results.Count | Should -Be 2
        
        $folderA = $results | Where-Object Name -eq "FolderA"
        $folderA.SizeMB | Should -Be 1.00
        $folderA.SizeBytes | Should -Be 1MB

        $folderB = $results | Where-Object Name -eq "FolderB"
        $folderB.SizeMB | Should -Be 2.00
        $folderB.SizeBytes | Should -Be 2MB
    }

    It "Accepts Path input from the pipeline" {
        $results = Get-Item $TestRoot | Get-FolderSize
        $results.Count | Should -Be 2
    }
}