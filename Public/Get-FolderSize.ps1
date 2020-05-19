function Get-FolderSize{
    [CmdletBinding()]
    param(
        [Parameter()]
        $Path = (Get-Location).Fullname
    )

    $Folders = Get-ChildItem -Path $Path -Directory

    foreach($Folder in $Folders){
        $Size = (Get-ChildItem -LiteralPath $Folder.Fullname -File -Recurse | Measure-Object -Sum -Property Length).Sum
        $Object = [PSCustomObject]@{
            SizeMB = [math]::Round($Size/1MB,2)
            Name = $Folder.Name
            Fullname = $Folder.Fullname
        }
        Write-Output $Object
    }
}