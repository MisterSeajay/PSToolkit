Describe "Convert-IniFileToVariables" {
    BeforeAll {
        $RootFolder = Join-Path -Path $PSScriptRoot -ChildPath ".." | Convert-Path
        $ModulePath = Join-Path $RootFolder "PSToolkit.psm1"
        Import-Module $ModulePath -Force

        # This command creates variables in a scope the caller can see, which for the
        # default is the global scope of the running process. Asserting that from inside
        # the test session would leave a $Port behind for every later test, so each case
        # runs in a child process and reports what that process can see.
        $PowerShellExe = (Get-Process -Id $PID).Path
        $script:Quote = [char]39

        # Runs a body in a child PowerShell, with the module already imported, and
        # returns its output. The body is written to a file and passed with -File
        # rather than -Command: a double quote inside a string handed to a native exe
        # is consumed by that exe's argument parser, which shows up as a parse error
        # in the child and reads like a bug in the code under test.
        function Invoke-InChildSession {
            param([string]$Body)

            $scriptPath = Join-Path ([System.IO.Path]::GetTempPath()) ("ini-" + [System.Guid]::NewGuid().ToString("N") + ".ps1")
            $preamble = 'Import-Module ' + $script:Quote + $ModulePath + $script:Quote + ' -Force' + [Environment]::NewLine
            [System.IO.File]::WriteAllText($scriptPath, $preamble + $Body)
            try {
                return , (& $PowerShellExe -NoProfile -File $scriptPath 2>&1 | Out-String)
            }
            finally {
                Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
            }
        }

        # The call plus a read-back of each named variable from the given scope.
        # Reporting absence as '<name>=<unset>' matters: a test that only greps for a
        # value cannot tell 'skipped' from 'created something else'.
        function Get-ChildVariableReport {
            param(
                [string]$IniPath,
                [string[]]$Names,
                [ValidateSet('Global', 'Script')]
                [string]$Scope = 'Global'
            )

            $nl = [Environment]::NewLine
            $q = $script:Quote
            $nameList = ($Names | ForEach-Object { $q + $_ + $q }) -join ', '

            $body = 'Convert-IniFileToVariables -Path ' + $q + $IniPath + $q + $nl +
                    'foreach ($n in @(' + $nameList + ')) {' + $nl +
                    '    $v = Get-Variable -Name $n -Scope ' + $Scope + ' -ErrorAction SilentlyContinue' + $nl +
                    '    if ($v) { $n + ' + $q + '=' + $q + ' + $v.Value } else { $n + ' + $q + '=<unset>' + $q + ' }' + $nl +
                    '}'

            return Invoke-InChildSession -Body $body
        }

        # Creating throwaway test data is not a state change that needs -WhatIf, and the
        # 'New' verb trips the ShouldProcess rule regardless.
        function New-IniFile {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '')]
            param([string[]]$Lines)

            $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("ini-" + [System.Guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            $path = Join-Path $dir "config.ini"
            [System.IO.File]::WriteAllLines($path, $Lines)
            return $path
        }

        function Remove-IniFile {
            param([string]$Path)
            $dir = Split-Path -Path $Path -Parent
            if ((Split-Path -Path $dir -Leaf) -like 'ini-*') {
                Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    AfterAll {
        Get-Module PSToolkit | Remove-Module -Force -ErrorAction SilentlyContinue
    }

    Context "Variable creation" {
        It "Creates a variable per key that the caller can actually see" {
            # The regression case. The command used New-Variable -Scope Script from
            # inside a module, which binds to the module's own script scope: the caller
            # saw nothing, and the variables vanished when the module was unloaded.
            $ini = New-IniFile -Lines @('[server]', 'Port=8080', 'Region=eu-west')
            try {
                $out = Get-ChildVariableReport -IniPath $ini -Names @('Port', 'Region')
                $out | Should -Match 'Port=8080'
                $out | Should -Match 'Region=eu-west'
            }
            finally {
                Remove-IniFile -Path $ini
            }
        }

        It "Puts the variables in the global scope by default" {
            # Read back from Global specifically, so the test pins the default rather
            # than observing only that some variable appeared somewhere.
            $ini = New-IniFile -Lines @('Port=8080')
            try {
                $out = Get-ChildVariableReport -IniPath $ini -Names @('Port') -Scope Global
                $out | Should -Match 'Port=8080'
            }
            finally {
                Remove-IniFile -Path $ini
            }
        }

        It "Keeps -Scope Script inside the module, where the caller cannot see it" {
            # Pinned deliberately rather than wished away. 'Script' resolves to the
            # module's own script scope, so this is the same visibility limit the
            # default Global exists to avoid. Global is the only scope that works,
            # and this test fails if that ever changes unnoticed.
            $ini = New-IniFile -Lines @('Port=8080')
            try {
                $nl = [Environment]::NewLine
                $q = $script:Quote
                $body = 'Convert-IniFileToVariables -Path ' + $q + $ini + $q + ' -Scope Script' + $nl +
                        '$inCaller = Get-Variable -Name Port -Scope Script -ErrorAction SilentlyContinue' + $nl +
                        '$inModule = Get-Module PSToolkit | ForEach-Object { & $_ { Get-Variable -Name Port -Scope Script -ErrorAction SilentlyContinue } }' + $nl +
                        '"caller=$([bool]$inCaller) module=$([bool]$inModule)"'

                $out = Invoke-InChildSession -Body $body
                $out | Should -Match 'caller=False module=True'
            }
            finally {
                Remove-IniFile -Path $ini
            }
        }

        It "Warns and skips a key that names a read-only automatic variable" {
            # 'Host' is read-only, and -Force cannot overwrite it, so an INI with a
            # host= key - entirely ordinary - cannot create $Host. The safety property
            # worth pinning is that PowerShell's own $Host survives and the rest of
            # the file still loads.
            $ini = New-IniFile -Lines @('Host=localhost', 'Port=8080')
            try {
                $nl = [Environment]::NewLine
                $q = $script:Quote
                $body = 'Convert-IniFileToVariables -Path ' + $q + $ini + $q + ' -WarningVariable warn' + $nl +
                        '"hostType=$($Host.GetType().Name)"' + $nl +
                        '"port=$Port"' + $nl +
                        '"warned=$([bool]$warn)"'

                $out = Invoke-InChildSession -Body $body
                $out | Should -Match 'port=8080'
                $out | Should -Match 'warned=True'
                $out | Should -Match 'hostType=InternalHost'
            }
            finally {
                Remove-IniFile -Path $ini
            }
        }

        It "Rejects a scope it does not support" {
            $ini = New-IniFile -Lines @('Port=8080')
            try {
                { Convert-IniFileToVariables -Path $ini -Scope 'Nowhere' } | Should -Throw
            }
            finally {
                Remove-IniFile -Path $ini
            }
        }

        It "Overwrites an existing variable of the same name" {
            $ini = New-IniFile -Lines @('Port=9999')
            try {
                $nl = [Environment]::NewLine
                $q = $script:Quote
                $body = '$Port = ' + $q + 'original' + $q + $nl +
                        'Convert-IniFileToVariables -Path ' + $q + $ini + $q + $nl +
                        '$Port'
                $out = Invoke-InChildSession -Body $body
                $out | Should -Match '9999'
            }
            finally {
                Remove-IniFile -Path $ini
            }
        }

        It "Takes a path from the pipeline" {
            $ini = New-IniFile -Lines @('Port=8080')
            try {
                $q = $script:Quote
                # Quoted, because a bare path at the start of a statement is parsed as a
                # command name and PowerShell tries to run the .ini file.
                $body = $q + $ini + $q + ' | Convert-IniFileToVariables' + [Environment]::NewLine +
                        '$v = Get-Variable -Name Port -Scope Global -ErrorAction SilentlyContinue' + [Environment]::NewLine +
                        'if ($v) { $v.Value }'
                $out = Invoke-InChildSession -Body $body
                $out | Should -Match '8080'
            }
            finally {
                Remove-IniFile -Path $ini
            }
        }
    }

    Context "INI syntax" {
        It "Ignores section headers" {
            $ini = New-IniFile -Lines @('[server]', '[database]', 'Port=8080')
            try {
                # Header names must come back unset, not merely be absent from the output.
                $out = Get-ChildVariableReport -IniPath $ini -Names @('Port', 'server', 'database')
                $out | Should -Match 'Port=8080'
                $out | Should -Match 'server=<unset>'
                $out | Should -Match 'database=<unset>'
            }
            finally {
                Remove-IniFile -Path $ini
            }
        }

        It "Skips comment lines, including ones containing an equals sign" {
            # A comment containing '=' passes the file's own "has a separator" filter, so
            # without an explicit check it would try to create a variable named '; Port'.
            $ini = New-IniFile -Lines @('; Port=1', '# Region=2', 'Port=8080')
            try {
                $out = Get-ChildVariableReport -IniPath $ini -Names @('Port', 'Region')
                $out | Should -Match 'Port=8080'
                $out | Should -Match 'Region=<unset>'
                $out | Should -Not -Match 'WARNING'
            }
            finally {
                Remove-IniFile -Path $ini
            }
        }

        It "Keeps an equals sign that appears inside a value" {
            $ini = New-IniFile -Lines @('Connection=Server=a;Database=b')
            try {
                $out = Get-ChildVariableReport -IniPath $ini -Names @('Connection')
                $out | Should -Match 'Connection=Server=a;Database=b'
            }
            finally {
                Remove-IniFile -Path $ini
            }
        }

        It "Errors when the file does not exist" {
            $missing = Join-Path ([System.IO.Path]::GetTempPath()) ("ini-missing-" + [System.Guid]::NewGuid().ToString("N") + ".ini")
            { Convert-IniFileToVariables -Path $missing } | Should -Throw
        }
    }
}
