Set-StrictMode -Version 2.0

# Dot-source all Private and Public helper scripts
foreach ($SubFolder in @('Private', 'Public')) {
    $Folder = Join-Path -Path $PSScriptRoot -ChildPath $SubFolder
    if (Test-Path -Path $Folder) {
        Get-ChildItem -Path $Folder -Filter '*.ps1' -File | ForEach-Object {
            . $_.FullName
        }
    }
}