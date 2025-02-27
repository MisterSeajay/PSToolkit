function GLOBAL:prompt {
    $host.UI.RawUI.WindowTitle = "$(Get-Location)"

    $width = $host.ui.rawui.WindowSize.Width
    $cwd = (Get-Location).Path.ToString()
    $drive = $cwd.Split('\')[0]

    while($cwd.Length -gt ($width - 40) -and $cwd.IndexOf('\') -gt 0)
    {
        $left   = $cwd.Split('\')[0]
        $length = $cwd.Length
        $cwd    = $cwd.SubString($left.Length+1,$length-($left.Length+1))
    }
    if($cwd.SubString(0,2) -ne $drive) {$cwd = $drive+"\...\"+$cwd}

    Write-Host -ForegroundColor DarkGray "`n[$cwd]"

    $id = 1
    $historyItem = Get-History -Count 1
    if($historyItem) {$id = $historyItem.Id + 1}

    Write-Host -ForegroundColor Yellow -NoNewLine "[PS:$id]"
    "> "
}

foreach ($path in ($env:PSModulePath -split (";"))) {
    $toolkit = Join-Path $path "PSToolkit"
    if ([System.IO.Directory]::Exists($toolkit)) {
        Write-Host "Importing $toolkit"
        Import-Module $toolkit
        break
    }
}