New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT

$guid = ([System.Guid]::NewGuid()).Guid

Write-Warning "Adding $guid"

$reg_data = @"
Windows Registry Editor Version 5.00

[HKEY_CLASSES_ROOT\CLSID\{$guid}]
"DescriptionID"=dword:00000003
"Infotip"=hex(2):40,00,25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,\
6f,00,74,00,25,00,5c,00,73,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,\
00,73,00,68,00,65,00,6c,00,6c,00,33,00,32,00,2e,00,64,00,6c,00,6c,00,2c,00,\
2d,00,31,00,32,00,36,00,39,00,30,00,00,00
"System.IsPinnedToNameSpaceTree"=dword:00000001

[HKEY_CLASSES_ROOT\CLSID\{$guid}\DefaultIcon]
@=hex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,\
00,5c,00,73,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,69,00,6d,00,\
61,00,67,00,65,00,72,00,65,00,73,00,2e,00,64,00,6c,00,6c,00,2c,00,2d,00,31,\
00,38,00,39,00,00,00

[HKEY_CLASSES_ROOT\CLSID\{$guid}\InProcServer32]
@=hex(2):25,00,73,00,79,00,73,00,74,00,65,00,6d,00,72,00,6f,00,6f,00,74,00,25,\
00,5c,00,73,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,73,00,68,00,\
65,00,6c,00,6c,00,33,00,32,00,2e,00,64,00,6c,00,6c,00,00,00
"ThreadingModel"="Both"

[HKEY_CLASSES_ROOT\CLSID\{$guid}\Instance]
"CLSID"="{0E5AAE11-A475-4c5b-AB00-C66DE400274E}"

[HKEY_CLASSES_ROOT\CLSID\{$guid}\Instance\InitPropertyBag]
"Attributes"=dword:00000011
"TargetKnownFolder"="{35286a68-3c57-41a1-bbb1-0eae73d76c95}"

[HKEY_CLASSES_ROOT\CLSID\{$guid}\ShellFolder]
"Attributes"=dword:f080004d
"FolderValueFlags"=dword:00000029
"SortOrderIndex"=dword:00000000

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{$guid}]
"@