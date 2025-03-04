<#
.SYNOPSIS
    Compares the folder contents of two different paths, with options to copy or
    delete source or target files, depending on their sync status.
.DESCRIPTION
    The .ps1 script creates and calls a function to perform the following actions:

    * Prompts for source and target paths, if not already provided
    * Checks that both paths exist
    * Counts the number of files in each path, recursively
    * Compares the source and target paths for missing files

    Note that it is assumed that the source path is authorative, i.e. that the
    files in the source will never be out-of-date compared to the target files.
.NOTES
    Filename: Sync-Folders.ps1
    Author:   Charles Joynt
.LINK
    http://www.joynt.co.uk/index.php/PowerShellSyncFolders
.OUTPUT
    By default, a logfile is created in the current working directory. A different
    path can be defined, but the logfile name will always be:

      Sync-Folders.YYYY-MM-DD_HH-mm.log
.EXAMPLE
    Sync-Folders.ps1 -InstallOnly
    Function Sync-Folders has been installed.
    InstallOnly switch detected. Script exiting.
.EXAMPLE
    Sync-Folders C:\Temp D:\Temp
    C:\Temp exists: True
    D:\Temp exists: True
#>
function Sync-Folders {
    param(
        $SourceDir = $(Read-Host "Enter source directory"),
        $TargetDir = $(Read-Host "Enter target directory"),
        $Exclude = $(Read-Host "Enter exclude string"),
        $LogPath = $(Get-Location),
        [switch]$PurgeTarget
    )

    $ErrorActionPreference = "Stop"

    $LogName = "Sync-Folders." + (Get-Date).ToString("yyyy-MM-dd_HH-mm") + ".log"
    $LogFile = Join-Path -Path $LogPath -ChildPath $LogName

    Write-Host $SourceDir exists: (Test-Path $SourceDir)
    Write-Host $TargetDir exists: (Test-Path $SourceDir)

    # Build lists of files
    $Status = "Building file arrays"
    $Status | Out-File -FilePath $LogFile

    Write-Progress -Activity "Sync-Folders" -Status "$Status" -PercentComplete 0 -Id 1

    $SourceList = Get-ChildItem -Path $SourceDir -Exclude "$Exclude" -Recurse | ?{$_.Mode -notmatch "^d.*"}

    $SourceCount = "Found " + ($SourceList.count) + " files in $SourceDir"
    $SourceCount | Out-File -FilePath $LogFile -Append

    $TargetList = Get-ChildItem -Path $TargetDir -Exclude "$Exclude" -Recurse | ?{$_.Mode -notmatch "^d.*"}

    $TargetCount = "Found " + ($TargetList.count) + " files in $TargetDir"
    $TargetCount | Out-File -FilePath $LogFile -Append

    # Build hash tables for each list
    $SourceHash = @{}
    $TargetHash = @{}

    foreach($File in $SourceList) {
        $RelativeFile = $File.FullName.SubString($SourceDir.Length+1,$File.FullName.Length-$SourceDir.Length-1)
        $SourceHash.Add($RelativeFile, $File.LastWriteTime)
    }

    foreach($File in $TargetList) {
        $RelativeFile = $File.FullName.SubString($TargetDir.Length+1,$File.FullName.Length-$TargetDir.Length-1)
        $TargetHash.Add($RelativeFile, $File.LastWriteTime)
    }

    # Find missing or out-of-date files in the target folder
    $sw = New-Object System.Diagnostics.Stopwatch
    $Counter = 0
    $FileUpdates = @()

    $Status = "Checking source folder"
    $Status | Out-File -FilePath $LogFile -Append

    Write-Progress -Activity "Sync-Folders" -Status "$Status" -PercentComplete 0 -Id 1

    $sw.Start()

    foreach($File in $SourceList) {
        # Update progress bar
        $Percent = [math]::min([math]::ceiling(($Counter++ / $SourceList.Count) * 100),100)

        if($sw.Elapsed.TotalSeconds -lt 5)
        {
            $SecondsRemaining = -1
        } else {
            $SecondsRemaining = $sw.Elapsed.TotalSeconds * (100 - $Percent)/$Percent
        }

        Write-Progress -Activity "$SourceCount" -Status "Scanning files" -Id 2 -ParentId 1 `
            -PercentComplete $Percent -SecondsRemaining $SecondsRemaining

        # Search for matching file
        $RelativeFile = $File.FullName.SubString($SourceDir.Length+1,$File.FullName.Length-$SourceDir.Length-1)

        if($TargetHash.Contains($RelativeFile)) {
            if($TargetHash.($RelativeFile) -lt $File.LastWriteTime) {
                "$File Out-of-date on target" | Out-File -FilePath $LogFile -Append
                # Write-Host $TargetHash.($RelativeFile)`t<->`t($File.LastWriteTime)
            }
        } else {
            "Found additional file " + $File.Fullname | Out-File -FilePath $LogFile -Append
        }
    }

    $sw.Reset()

    # Find target files that are missing in the source folder
    $Counter = 0

    $Status = "Checking target folder"
    $Status  | Out-File -FilePath $LogFile -Append

    Write-Progress -Activity "Sync-Folders" -Status "$Status" -PercentComplete 50 -Id 1

    $sw.Start()

    foreach($File in $TargetList) {
        # Update progress bar
        $Percent = [math]::min([math]::ceiling(($Counter++ / $SourceList.Count) * 100),100)

        if($sw.Elapsed.TotalSeconds -lt 5) {
            $SecondsRemaining = -1
        } else {
            $SecondsRemaining = $sw.Elapsed.TotalSeconds * (100 - $Percent)/$Percent
        }

        Write-Progress -Activity "$TargetCount" -Status "Scanning files" -Id 3 -ParentId 1 `
            -PercentComplete $Percent -SecondsRemaining $SecondsRemaining

        # Search for matching file
        $RelativeFile = $File.FullName.SubString($TargetDir.Length+1,$File.FullName.Length-$TargetDir.Length-1)

        if(-not($SourceHash.Contains($RelativeFile))) {
            "Found additional file " + $File.Fullname | Out-File -FilePath $LogFile -Append
        }
    }

    $sw.Stop()

    # Close the progress bars
    Write-Progress -Activity "$TargetCount" -Status "Complete" -Complete -Id 3 -ParentId 1
    Write-Progress -Activity "$SourceCount" -Status "Complete" -Complete -Id 2 -ParentId 1
    Write-Progress -Activity "Sync-Folders" -Status "Complete" -Complete -Id 1
}