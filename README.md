# PSToolkit

A small PowerShell module of filesystem helpers, plus a few string and
configuration utilities. The filesystem side is the substantial part: a data
command that walks a hierarchy and a separate renderer that draws it, so you can
either pipe the result somewhere or just look at it.

The module is the part with tests, a manifest and a licence. The scripts in
`Scripts/` are developer utilities and are not exported.

## Requirements

Windows PowerShell 5.1 or later. The module is tested on 5.1, which is why every
PowerShell source file is stored as UTF-8 *with* a byte-order mark: 5.1 reads a
BOM-less file as ANSI and renders box-drawing characters as mojibake.

Not published to the PowerShell Gallery. Install from a clone.

## Installation

```powershell
git clone https://github.com/MisterSeajay/PSToolkit.git
Import-Module .\PSToolkit\PSToolkit.psd1
```

To produce a folder you can copy into a module path:

```powershell
.\Scripts\Build-Module.ps1 -OutputPath C:\Modules\PSToolkit
Import-Module C:\Modules\PSToolkit\PSToolkit.psd1
```

## Repository layout

```text
Public/         exported functions, one Verb-Noun function per file
Private/        internal helpers, dot-sourced by the .psm1
Tests/          Pester tests
Scripts/        developer utilities; not part of the module
```

Only `Public/` is the module. `Scripts/` is not exported and is not covered by
the module's contract, so the two are not interchangeable. `AGENTS.md` 2.1 has
the full layout and the conventions behind it.

## Commands

| Command | What it does |
| --- | --- |
| `Format-Tree` | Draws a directory hierarchy to the host. Aliased to `tree`. |
| `Get-FolderStructure` | Returns a directory hierarchy as objects, one per item. |
| `Get-EmptyFolder` | Finds directories that contain nothing at all. |
| `Get-FolderSize` | Gets the size of subdirectories in the specified path. |
| `Import-IniFile` | Converts an INI file's contents to PowerShell variables. |
| `ConvertTo-TitleCase` | Capitalizes initial letters of words in a text string. |

`tree` is an alias for `Format-Tree`, so it is a drop-in replacement for the
cmd.exe `tree` command, including `tree` on its own for the current directory.

## Usage

### Draw a directory tree

```powershell
tree -Path C:\Projects
```

```text
Projects/
├── docs/
│   └── guide.md
├── empty/
├── src/
│   ├── assets/
│   │   └── logo.png
│   └── app.ps1
└── README.md
```

With no arguments, `tree` draws the current location.

### Work with the hierarchy as data

`Get-FolderStructure` returns objects, so it filters and sorts like anything
else. Pipe it to `Format-Tree` to draw it, or use the `tree` alias for that.

```powershell
Get-FolderStructure -Path C:\Projects -Directory |
    Select-Object Name, Depth
```

```text
Name      Depth
----      -----
Projects      0
docs          1
empty         1
src           1
assets        2
```

### Find empty directories

```powershell
Get-EmptyFolder -Path C:\Projects
```

```text
Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----        27/09/2026     14:38                empty
```

Each result is a `System.IO.DirectoryInfo`, so it pipes onward.

### Measure subdirectory sizes

```powershell
Get-FolderSize -Path C:\Projects | Sort-Object SizeBytes -Descending
```

```text
Name   SizeMB SizeBytes
----   ------ ---------
assets      3   3145728
src       0.5    524288
docs     0.02     20480
```

Sizes are reported per subdirectory, not for the root itself.

### Load an INI file into variables

```powershell
Import-IniFile -Path .\config.ini
```

Given a `config.ini` containing:

```ini
[server]
; comments are skipped
Port=8080
```

`$Port` is set to `8080` afterwards. Section headers are ignored, and a key that
names a read-only automatic variable such as `Host` cannot be assigned even with
`-Force`: that line warns and is skipped, and the rest of the file still loads.

### Capitalize words

```powershell
ConvertTo-TitleCase -Text "the quick brown-fox"
```

```text
The Quick Brown-Fox
```

## Help

The README describes the project. `Get-Help` describes the commands, including
every parameter, and is the only place that detail lives:

```powershell
Get-Help Get-FolderStructure -Full
Get-Help Get-FolderStructure -Parameter Exclude
Get-Command -Module PSToolkit
```

## Development

```powershell
.\Scripts\Invoke-Pester.ps1                                  # run the test suite
Invoke-ScriptAnalyzer -Path ./ -Recurse                      # lint PowerShell
markdownlint-cli2 "**/*.md"                                  # lint Markdown
.\Scripts\Build-Module.ps1 -OutputPath "C:\some\output"      # build; runs tests first
```

Pester 5 or later, PSScriptAnalyzer and markdownlint-cli2 are needed to develop
the module, not to use it. `Invoke-Pester.ps1` exits non-zero on any failure,
including a test file that fails to load, so it is safe to use as a CI gate.
`Build-Module.ps1` runs the suite first and refuses to build if it is not green.

A pre-commit hook lints staged Markdown, so the documentation rules are checked
before a commit rather than after. It is off by default, because git stores the
hooks path as local configuration, so enable it once per clone:

```powershell
git config core.hooksPath .githooks
```

The hook fails the commit if markdownlint-cli2 is not installed rather than
skipping the check quietly. `git commit --no-verify` bypasses it on purpose.

`Build-Module.ps1` derives the export lists from `Public/` and writes them back
into `PSToolkit.psd1` in the source tree, so expect that one file to be modified
by a build.

`AGENTS.md` holds the conventions this code follows, and records the reasoning
behind the ones that are not obvious. `TODO.md` tracks outstanding work, known
gaps and decisions still open; it is a working document for contributors, not
documentation for users.

## Deliberate exceptions

Recorded here rather than left to look like oversights:

- **`Get-FolderStructure.LegacyArgs` is deliberately undocumented.** It is a
  shim that swallows cmd.exe-style `/A` and `/F` flags so the old `tree` calling
  convention does not error. Documenting it would advertise a dead convention.
  Retiring it would be a fair future change.
- **The two `-Exclude` parameters differ slightly.** `Get-FolderStructure`
  prunes a directory that matches and never walks into it; `Get-EmptyFolder`
  scans everything and merely omits matches from its results. Both match
  wildcards against the item's name, following `Get-ChildItem -Exclude`.
- **`Format-Tree` cannot draw nothing.** Given neither pipeline input nor
  `-Path` it draws the current location, and PowerShell cannot distinguish an
  empty pipeline from no pipeline. A pipeline that yields nothing therefore draws
  the current location too.
- **`Import-IniFile` only works in the global scope.** A function
  inside a module runs in the module's scope, so `-Scope Script` and `-Scope
  Local` create variables the caller cannot read. `Global` is the default for
  that reason.
- **The root directory is always emitted by `Get-FolderStructure`,** even under
  `-File`, so the result keeps an anchor for the renderer to draw from.

## Licence

MIT. See [LICENSE](LICENSE).
