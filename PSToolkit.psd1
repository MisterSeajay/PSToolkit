@{
    RootModule        = '.\PSToolkit.psm1'
    ModuleVersion     = '1.0.0.1'
    GUID              = '0b3cf5dd-e616-4f84-9e84-15083fa307f3'
    Author            = 'MisterSeajay'
    CompanyName       = 'MisterSeajay'
    Copyright         = 'MisterSeajay'
    Description       = 'Useful PowerShell functions and utilities.'
    PowerShellVersion = '5.1'

    # Explicit exports speed up module auto-discovery and import performance
    FunctionsToExport = @(
        'ConvertTo-TitleCase',
        'Format-Tree',
        'Get-EmptyFolder',
        'Get-FolderSize',
        'Get-FolderStructure',
        'Import-IniFile'
    )

    AliasesToExport   = @(
        'tree'
    )

    # Do not leak internal script variables into the caller environment
    VariablesToExport = @()
    CmdletsToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('PowerShell', 'Toolkit')
            LicenseUri   = 'https://github.com/MisterSeajay/PSToolkit/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/MisterSeajay/PSToolkit'
            ReleaseNotes = 'https://github.com/MisterSeajay/PSToolkit/blob/main/README.md'
        }
    }
}
