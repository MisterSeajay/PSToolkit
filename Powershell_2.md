# PSToolkit

## 2.1 What this project is

A small PowerShell module of filesystem helpers, plus a handful of standalone
utility scripts. The module is the part with tests, a manifest and a licence;
the scripts in `Scripts/` are developer utilities, some of which write to the
registry and need elevation.

## 2.2 Layout

```text
Public/         exported functions, one Verb-Noun function per file
Private/        internal helpers, camelCase, dot-sourced by the .psm1
Tests/          Pester tests, one file per public function plus infrastructure
Scripts/        developer utilities: build, test runner, one-off helpers
PSToolkit.psd1   manifest, including the generated export lists
PSToolkit.psm1   loader; dot-sources Private/ then Public/

```

Only `Public/` is the module. `Scripts/` is not exported and is not covered by
the module's contract — do not treat the two as interchangeable.

**The module separates data from presentation.** `Get-`-style functions return
objects; `Format-Tree` is the only thing that writes a rendered tree to the host.
When adding a command, decide which side of that line it belongs on before writing
it, because the two halves have different testing needs: data can be asserted
directly, whereas host output has to be captured from the information stream.

## 2.3 Commands

```powershell
.\Scripts\Invoke-Pester.ps1                                 # run the test suite
Invoke-ScriptAnalyzer -Path ./                              # lint
.\Scripts\Build-Module.ps1 -OutputPath "C:\some\output"    # build; runs tests first
Import-Module .\PSToolkit.psd1 -Force                       # import for testing

```

`Build-Module.ps1` derives `FunctionsToExport` from `Public/` via the AST,
rewrites the manifest, and **aborts if the Pester run has any failure**. A green
suite is therefore a precondition for building, not just good hygiene.

The abort covers a test file that fails to *load* as well as one that fails —
see 1.8 for why counting only `FailedCount` is not enough. If Pester 5+ is not
installed the gate is skipped with a warning, so a build can be unverified;
treat that warning as an error in any automated pipeline.

Two bugs here were fixed and are easy to reintroduce. `$ModuleRoot` was used
before it was assigned, so the script failed on its first statement. And Pester
was probed with `Get-Module -ListAvailable`, which lists without loading, so
`[PesterConfiguration]` never resolved and the gate was skipped while the build
still reported success. Both produced a green result from work that never ran.

## 2.4 Requirements

Windows PowerShell 5.1 or later. The module is tested on 5.1, which is why the
UTF-8 BOM is mandatory rather than cosmetic — see 1.1. Pester 5+ and
PSScriptAnalyzer are needed only for development, not to consume the module.

## 2.5 Traps specific to this repository

* **The dynamic-scoping trap described in 1.9 has been fixed here.**
`Get-FolderStructure` used to delegate to a private helper that read `$Exclude`,
`$File`, `$Directory` and `$MaxDepth` straight out of its caller's scope. Traversal
now lives in `Private/getTreeNodes.ps1`, which takes all of them as explicit
parameters. If you add a private helper, pass its inputs; do not rely on the
caller's variables being visible.
* **`Get-FolderStructure` returns objects; `Format-Tree` draws them.** The split is
deliberate: the data function pipes and filters, the renderer owns `Write-Host`.
The `tree` alias points at `Format-Tree`, not at `Get-FolderStructure`, so that
`tree` and `tree <path>` keep printing a tree. If you add a renderer, preserve that
alias behaviour.
* **Sibling "lastness" in `Format-Tree` is subtle and was wrong twice.** Two plausible
shortcuts fail: comparing only the next node breaks for a node with children,
because the next node is its own child; comparing depths across the whole sequence
breaks because two nodes at the same depth in different subtrees are not siblings.
It needs the stack-based forward pass that is there now, and
`Tests/Format-Tree.tests.ps1` pins both cases.
* **`Build-Module.ps1` updates the root `PSToolkit.psd1` and copies `*.ps1`
only.** It writes no per-function manifests, and it does not copy `LICENSE` or
the `Tests/` folder into the output. `LicenseUri` is a GitHub URL, so it still
resolves, but the built module is not self-contained.
* **`PSToolkit.psd1` is UTF-8 *with* BOM.** Any script that rewrites the
manifest must use `UTF8Encoding($true)`. A `Get-Content` / `Set-Content`
round-trip will strip the BOM.
* **`Get-FolderStructure` writes to the host,** so its output is not pipeable.
Tests capture it with `6>&1`. See 1.3.
* **`Get-FolderStructure.LegacyArgs` is deliberately undocumented.** It is a
`ValueFromRemainingArguments` shim that swallows cmd.exe-style `/A` and `/F`
flags from the old `tree` command. It is allowlisted in
`Tests/PSToolkit.tests.ps1` and documented in a comment there. Documenting it
would advertise a dead calling convention. Retiring the parameter is a fair
future change.
* **Exclusion semantics differ slightly between the two traversal commands.**
Both now match names with wildcards per 1.5, but `Get-FolderStructure` prunes
an excluded directory without walking into it, while `Get-EmptyFolders` still
scans everything and merely omits excluded directories from the results.

## 2.6 Documentation

The README describes the project, installation, usage and development
requirements. `Get-Help` describes the commands. They must not overlap — see
1.4. `Tests/PSToolkit.tests.ps1` enforces the help rules, so help gaps fail the
build rather than being discovered by a reader.

`TODO.md` tracks deferred work: what is outstanding, what was deliberately not
done and why, and which decisions are still open. Read it at the start of a
session and update it when something lands or gets deferred — a decision made
in conversation and not written down is lost. It is a working document, not
documentation, so it does not belong in the README.
