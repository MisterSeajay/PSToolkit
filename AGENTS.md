# PowerShell Development Guidelines

Conventions for writing PowerShell modules, and for writing PowerShell that
other people have to maintain. Section 1 is deliberately project-agnostic and
can be copied into any repository. Section 2 covers this repository only.

When a rule and existing code disagree, fix the code. Record any deliberate
exception in Section 2 rather than quietly violating the rule.

---

# Section 1: Portable guidelines

## 1.1 Encoding and line endings

**Store `.ps1`, `.psd1` and `.psm1` files as UTF-8 *with* a byte-order mark.**

Windows PowerShell 5.1 reads a file with no BOM as ANSI (Windows-1252). Any
non-ASCII character — box-drawing characters, accented text, emoji, smart
quotes — is then decoded wrongly and appears as mojibake. PowerShell 7+ detects
UTF-8 without a BOM, so a file can pass locally and break for every 5.1 user.
Adding a BOM is correct for both.

The BOM is committed to the repository. Do not use git's
`working-tree-encoding=UTF-8-BOM` attribute to synthesise it on checkout: the
git documentation describes that attribute as not recommended, and it
complicates renormalisation.

Keep Markdown, JSON and other data files as UTF-8 *without* a BOM.

**Add a `.gitattributes` so line endings do not depend on each machine:**

```gitattributes
* text=auto eol=crlf
```

That stores LF in the repository and checks out CRLF in the working tree. Without
it, a file's line endings depend on whatever `core.autocrlf` the contributor
happens to have, and the same file differs between clones.

**Never round-trip source through `Get-Content` / `Set-Content`.** Those cmdlets
infer encoding on read and pick a default on write, which silently rewrites
BOMs and line endings. Use explicit encodings:

```powershell
$text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
$text = $text -replace "(?<!`r)`n", "`r`n"
[System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($true))
```

Note the `$true`: it emits the BOM. The parameterless `UTF8` does not, and will
strip one.

**Detect encoding before editing a file programmatically.** UTF-16 appears with
either byte order, and checking only for one of them silently rewrites the file
as UTF-8:

| Bytes at offset 0 | Encoding |
| --- | --- |
| `FF FE` | UTF-16 LE |
| `FE FF` | UTF-16 BE |
| `EF BB BF` | UTF-8 with BOM |
| anything else | UTF-8 / ASCII |

**Verify edits by byte count, and use `GetByteCount`.** A one-character change is
not always a one-byte change: a box-drawing character is one character and three
UTF-8 bytes. Check `expected = 3 + $encoding.GetByteCount($text)` rather than
`3 + $text.Length`, or a correct file will look corrupt.

**Use literal `.Replace()`, not `-replace`, for programmatic edits.** In a
`-replace` replacement string, `$_` and `$1` are interpolated by PowerShell
before the regex engine sees them, so editing a line containing `$_` splices in
the wrong text. Use `[string]::Replace($old, $new)`, or escape as `$$`.

## 1.2 Functions and parameters

**Use approved verbs, and Verb-Noun naming.** Check with `Get-Verb`. Public
functions are `Verb-Noun`; private helpers may be `camelCase`.

**Name the file after the function it contains**, so a function called
`Get-Report` lives in a file called `Get-Report.ps1`.

**`[CmdletBinding()]` goes in the function's attribute list, before `param`:**

```powershell
function Get-Example {
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateScript({ Test-Path $_ })]
        [string]$Path
    )
}
```

Placing `[CmdletBinding()]` *inside* the `param()` parentheses makes it a
per-parameter attribute. It is then silently ignored: the function gets no
`-Verbose`, no `-ErrorAction`, and no `$ErrorActionPreference` integration, and
no error is raised. A test that only checks the function runs will not catch it —
assert that `$func.Parameters.ContainsKey('Verbose')`.

**Always declare a type for every parameter.** Untyped parameters become
`[object]`, which forces casts downstream.

**Use attributes for validation** — `ValidateSet`, `ValidatePattern`,
`ValidateRange`, `ValidateScript` — rather than hand-rolled `if` blocks. They
fail at parameter binding, with a message that names the parameter.

**Use `$PSBoundParameters`, not `$null -ne $x`, to detect an explicit argument.**
A parameter with a default is never `$null`; `$PSBoundParameters` distinguishes
"caller passed this" from "caller did not".

**Use `[switch]` for booleans, and `ParameterSetName` for modes.** A
`[switch]$Directory` is unambiguous on the command line; a `[bool]$Directory`
accepts `$false`, which is almost never what the user meant. Mutually exclusive
modes belong in separate parameter sets so the binding engine rejects the
invalid combination:

```powershell
[CmdletBinding(DefaultParameterSetName = 'All')]
param(
    [Parameter(ParameterSetName = 'DirectoryOnly')][switch]$Directory,
    [Parameter(ParameterSetName = 'FileOnly')][switch]$File
)
```

**Use `Set-StrictMode -Version 2.0`** in modules and scripts. It turns typos and
unset variables into errors instead of silent `$null`.

## 1.3 Output and the pipeline

**Return objects, not formatted text.** Callers may want to filter, sort or
count the result. A function that returns a pre-formatted string cannot be
composed.

**Reserve `Write-Host` for messages addressed to a person.** It writes to the
host, not the pipeline, so the output cannot be piped, assigned, or asserted on
in a test. A tree-drawing command is a legitimate use — but document it, and
expect to capture it in tests with `6>&1`.

**Return `[System.IO.DirectoryInfo]` / `[FileInfo]`, not strings**, and declare
`[OutputType()]` so consumers can discover it.

## 1.4 Comment-based help is the source of truth

Comment-based help is the only documentation that travels with the code: it
works on an installed copy, renders in `Get-Help`, and is what the PowerShell
Gallery shows. A separate docs site drifts from the code and nothing detects it.

**The README describes the project. `Get-Help` describes the commands. They do
not overlap.** The README may list commands and show one example each. Parameter
types, defaults, and per-parameter semantics belong in `.PARAMETER` blocks and
nowhere else.

**A public function needs, at minimum:** `.SYNOPSIS`, `.DESCRIPTION`, a
`.PARAMETER` entry for every declared parameter, at least one `.EXAMPLE`, and
`.NOTES` for caveats. Place the help block inside the function body.

**`[Parameter(HelpMessage = "...")]` is not documentation.** It appears in
locally generated help, which makes an undocumented function look documented. It
does not appear in `Get-Help -Online` or on the Gallery. Do not use it as a
substitute for a help block.

**`.LINK` versus `HelpUri`:** `.LINK` is a normal keyword and always works.
`HelpUri` is what `Get-Help -Online` needs, and it must be an absolute URL to a
rendered page — a `blob/` URL to raw source will not serve as help. Choose
deliberately; do not set a `HelpUri` that does not actually resolve.

### Tooling gotchas when reading help from the AST

If you write tooling or tests that inspect help, note:

- `GetHelpContent()` returns **null** on the file-level `ScriptBlockAst`. Call it
  on the `FunctionDefinitionAst`.
- `CommentHelpInfo.Parameters` is a `Dictionary[String, String]`, not a
  collection of objects. Read names from `.Keys` — `.Parameters.Parameter` is
  `$null`, and `@($null)` looks like a one-element list with an empty name.
- The parser **upper-cases** those keys, and the dictionary is case-sensitive on
  lookup. Normalise before indexing, or compare case-insensitively.

## 1.5 Behave like the cmdlet you are imitating

**When a parameter name copies a built-in, copy its semantics too.** A
parameter that behaves differently from the cmdlet users already know is worse
than a differently named one.

`Get-ChildItem -Exclude` is the reference for exclusion parameters:

- patterns are **wildcards**, tested against the item's **name** (the leaf), not
  its full path
- matching is case-insensitive
- a directory that matches is **pruned**, not descended into
- it takes one or more patterns

`Get-ChildItem -ExcludePath` does **not** exist in Windows PowerShell 5.1, so do
not design against it unless the module declares a higher minimum version.

Two `-Exclude` parameters in the same module must behave identically. When more
than one command needs the same matching, put it in one shared private helper so
the two cannot drift apart.

## 1.6 Module structure

**Ship a `.psd1` manifest and a `.psm1` loader.** The manifest is the contract;
keep it valid by asserting `Test-ModuleManifest` passes.

**Dot-source `Private/` then `Public/`** so definitions are available regardless
of alphabetical order:

```powershell
Set-StrictMode -Version 2.0
foreach ($sub in @('Private', 'Public')) {
    Get-ChildItem -Path (Join-Path $PSScriptRoot $sub) -Filter '*.ps1' -File |
        ForEach-Object { . $_.FullName }
}
```

**Derive `FunctionsToExport` from the `Public/` folder** using the AST, and write
it into the manifest at build time. A hand-maintained list drifts, and a
forgotten entry means the function still works locally but is missing for
everyone who installs the module.

**`PSData` URIs must actually resolve.** `ProjectUri`, `LicenseUri` and
`ReleaseNotes` are shown to Gallery users; check that each returns HTTP 200. A
link to an empty wiki, or to a licence file that does not exist, is a broken
promise. Prefer a file in the repository over a wiki you have not written yet.

**Do not ship stale generated artefacts.** If a build step writes a `.psd1`
alongside a `.psm1`, the `.psm1` remains the source of truth and the `.psd1` is
disposable. Make this explicit so nobody edits the generated copy.

## 1.7 Error handling

- **`throw` for programmer errors** — a bad argument the caller controls is
  usually a binding-time failure via validation attributes; use `Write-Error` for
  runtime conditions.
- **Set `-ErrorAction Stop` inside `try`** when you intend to `catch`. Without
  it, a non-terminating error does not enter the block.
- **Never swallow an exception.** An empty `catch` hides the failure. If
  continuing is correct, say so in a warning and explain what was skipped.
- **Partial-failure traversal should warn and continue.** A recursive walk that
  meets one access-denied directory should report it and keep going, rather than
  aborting everything. A bulk operation where one failure means the whole result
  is wrong should fail hard — pick per operation and document the choice.

## 1.8 Testing

**Pester 5 or later.** Structure tests as `Describe` / `Context` / `It`.

**A test that has never failed proves nothing.** When you add an assertion,
temporarily break the code and confirm the test goes red *for the stated reason*.
Also assert the file still parses, so you can distinguish a behavioural failure
from a syntax error:

```powershell
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors) | Out-Null
@($errors).Count | Should -Be 0
```

**Aggregate problems, then assert empty.** Collecting every failure into a list
and asserting it is empty reports all the problems in one run instead of one per
run:

```powershell
$problems = [System.Collections.Generic.List[string]]::new()
# ... $problems.Add("...") per issue ...
($problems -join [Environment]::NewLine) | Should -BeNullOrEmpty
```

**A test file that cannot be parsed never reports a failed test.** It produces a
failed *container*, so a gate that checks only `FailedCount` sees zero failures
and reports a broken suite as green. Check all three:

```powershell
$failures = $result.FailedCount + $result.FailedContainersCount + $result.FailedBlocksCount
```

Report containers and blocks separately from tests in the message, otherwise
"0 test(s) failed" reads as success rather than as a suite that never ran. Have
the runner exit non-zero, so a calling script or CI job fails with it.

**Do not gate on a check that can be skipped silently.** If a lint or test step
is conditional on a tool being installed, warn loudly when it is skipped —
otherwise an unverified build looks exactly like a verified one.

**`-ForEach` is evaluated at discovery time, before `BeforeAll` runs.** Anything
`BeforeAll` defines — variables, helper functions — does not exist yet. Define
fixtures in a function and call it from the test body, or use a plain loop.

**`Import-Module Pester` before touching `[PesterConfiguration]`** in a fresh
session, or the type does not resolve and the configuration silently becomes
`$null`.

**Test behaviour, not implementation.** For `Write-Host` output, capture the
information stream: `(Get-Example 6>&1 | Out-String)`.

**Make a linter a gate, not advice.** Run PSScriptAnalyzer in the test suite so
a violation fails the build.

**Guard documentation with tests.** Because help is the source of truth, a test
should fail when a public function loses its help block, its `.SYNOPSIS`, or a
`.PARAMETER` entry. Keep an explicit, commented allowlist of parameters that are
deliberately undocumented, so a new undocumented parameter still fails.

## 1.9 Pitfalls worth knowing

- **Dynamic scoping leaks caller variables.** A function can read a variable it
  never declared, because it exists in the caller's scope. A helper called as
  `Build-Node -Item $dir` that then reads `$MaxDepth` from the function that
  called it will work, be invisible in its own signature, and break silently on
  refactor. Pass such values as explicit parameters.
- **`-eq` against an array filters instead of returning a boolean.**
  `@('a','b','c') -eq 'b'` returns a one-element array containing `b`, and any
  non-empty array is truthy, so `if ($array -eq 'x')` is true whenever *any*
  element matches. Use `-contains` / `-notcontains`, which read as the question
  you meant.
- **Nested `Where-Object` scripts both use `$_`.** Capture the outer value in a
  local before entering the inner block, or the pattern is tested against the
  wrong object.
- **`Get-ChildItem` returns `[DateTime]`, not strings,** for `LastWriteTime` and
  friends. String operations and `[datetime]` casts behave differently than
  expected.
- **Exact matching is rarely what a user wants from a filter.** `-notcontains`
  needs an exact, case-insensitive name and silently ignores wildcards, so
  `-Exclude '*.log'` does nothing. Prefer `-like` / `-notlike` for patterns.

---

# Section 2: This repository

Everything above applies to any PowerShell project. This section applies only
here and is removed when the guidelines are copied elsewhere.

## 2.1 What this project is

A small PowerShell module of filesystem helpers, plus a handful of standalone
utility scripts. The module is the part with tests, a manifest and a licence;
the scripts in `Scripts/` are developer utilities, some of which write to the
registry and need elevation.

## 2.2 Layout

```text
Public/     exported functions, one Verb-Noun function per file
Private/    internal helpers, camelCase, dot-sourced by the .psm1
Tests/      Pester tests, one file per public function plus infrastructure
Scripts/    developer utilities: build, test runner, one-off helpers
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
.\Scripts\Invoke-Pester.ps1                                  # run the test suite
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

- **The dynamic-scoping trap described in 1.9 has been fixed here.**
  `Get-FolderStructure` used to delegate to a private helper that read `$Exclude`,
  `$File`, `$Directory` and `$MaxDepth` straight out of its caller's scope. Traversal
  now lives in `Private/getTreeNodes.ps1`, which takes all of them as explicit
  parameters. If you add a private helper, pass its inputs; do not rely on the
  caller's variables being visible.
- **`Get-FolderStructure` returns objects; `Format-Tree` draws them.** The split is
  deliberate: the data function pipes and filters, the renderer owns `Write-Host`.
  The `tree` alias points at `Format-Tree`, not at `Get-FolderStructure`, so that
  `tree` and `tree <path>` keep printing a tree. If you add a renderer, preserve that
  alias behaviour.
- **Sibling "lastness" in `Format-Tree` is subtle and was wrong twice.** Two plausible
  shortcuts fail: comparing only the next node breaks for a node with children,
  because the next node is its own child; comparing depths across the whole sequence
  breaks because two nodes at the same depth in different subtrees are not siblings.
  It needs the stack-based forward pass that is there now, and
  `Tests/Format-Tree.tests.ps1` pins both cases.
- **`Build-Module.ps1` updates the root `PSToolkit.psd1` and copies `*.ps1`
  only.** It writes no per-function manifests, and it does not copy `LICENSE` or
  the `Tests/` folder into the output. `LicenseUri` is a GitHub URL, so it still
  resolves, but the built module is not self-contained.
- **`PSToolkit.psd1` is UTF-8 *with* BOM.** Any script that rewrites the
  manifest must use `UTF8Encoding($true)`. A `Get-Content` / `Set-Content`
  round-trip will strip the BOM.
- **`Get-FolderStructure` writes to the host,** so its output is not pipeable.
  Tests capture it with `6>&1`. See 1.3.
- **`Get-FolderStructure.LegacyArgs` is deliberately undocumented.** It is a
  `ValueFromRemainingArguments` shim that swallows cmd.exe-style `/A` and `/F`
  flags from the old `tree` command. It is allowlisted in
  `Tests/PSToolkit.tests.ps1` and documented in a comment there. Documenting it
  would advertise a dead calling convention. Retiring the parameter is a fair
  future change.
- **Exclusion semantics differ slightly between the two traversal commands.**
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
