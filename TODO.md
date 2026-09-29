# TODO

Working list for PSToolkit. Items persist between sessions; check this file at
the start of a session and update it as things land.

Rules for this file:

- Tick a box only when the item is verified, not when the code compiles.
- Record the reason for a deliberate non-action, so it is not re-litigated.
- Add a new item the moment something is deferred rather than dropped.

Guidance for the project lives in `AGENTS.md`; cmdlet detail lives in
`Get-Help`. Neither duplicates what is tracked here.

`AGENTS.md` no longer has a repository-specific section, and it now says a
deliberate exception is recorded in `README.md`. So this file is no longer
pointed at from anywhere: nothing tells a future session to read it. Needs a
decision — see below.

## Documentation

- [x] **Rewrite the README.** It is still the original two lines, so the repo
  has six exported commands, an MIT licence and almost no documentation.
  Per `AGENTS.md` 1.4 it covers the project, installation, usage and
  development requirements, and points at `Get-Help` for parameter
  detail. Done when a reader can install the module and run their first
  command from the README alone.

  Written, and every one of the 11 command lines it publishes was run before
  being written down. Four of the first drafts did not work and were corrected
  rather than published: `Get-FolderSize` has no `Size` property, `-MaxDepth 1`
  emits the root alone, `Convert-IniFileToVariables` created nothing the caller
  could see, and bare `tree` printed nothing. Two of those were product bugs and
  are fixed; see the commit before this one. Lints clean under
  `markdownlint-cli2`, UTF-8 without a BOM, CRLF.

- [ ] **Decide where a future session is pointed at this file.** `AGENTS.md`
  2.6 used to say "read TODO.md at the start of a session"; that section
  has been rewritten and the pointer is gone. The new `AGENTS.md` says a
  deliberate exception belongs in `README.md`, which is a different thing:
  a README is read by users, and this list is not for them. Options: add a
  short contributor note back, move the deferred-work items into
  `AGENTS.md`, or accept that this file is only found by opening it.

  Partly answered for now: the README's Development section points at both this
  file and `AGENTS.md`, so a contributor who reads the README finds them.

## Rules the code does not yet meet

Found by auditing the code against the rewritten `AGENTS.md`, not by a failure.

- [x] **Five public functions accept pipeline input but have no `end` block.**
  `AGENTS.md` 1.2 now requires explicit `begin` / `process` / `end` on any
  function taking `ValueFromPipeline`, because a function body with no
  sections only sees the last pipeline object. Missing from
  `Convert-IniFileToVariables`, `ConvertTo-CapitalizedWords`,
  `Get-EmptyFolders`, `Get-FolderSize` and `Get-FolderStructure`. All five
  currently work, because each is invoked with one object at a time or
  aggregates outside the loop — but that is luck, not design. Mechanical
  fix, worth doing as its own change so a diff stays reviewable.

  Checked each of the five before changing anything: all of them put the whole
  of their work in `process` and accumulate nothing, so the `end` blocks are
  empty and the change is structural, with no behaviour difference. That is the
  form `AGENTS.md` 1.2's own example shows.

  Guarded by a new test in `Tests/PSToolkit.tests.ps1` that reads the AST rather
  than the source text, so a block written on one line is not mistaken for a
  missing one. Removing one `end` block turns it red naming the file and the
  function.

  The first version of that test was red for the wrong reason: it tested
  `-isnot [System.Management.Automation.Language.ParameterAttributeAst]`, and
  that type does not exist in Windows PowerShell 5.1, so it would have failed on
  every input including correct code. `[Parameter()]` is an `AttributeAst` whose
  `TypeName.Name` is `Parameter`. A gate that cannot go green is not a gate.

- [ ] **`Convert-IniFileToVariables` is a modifying command with no
  `-WhatIf`.** It creates variables in the caller's session, and
  `AGENTS.md` 1.2 requires `SupportsShouldProcess` for anything that
  modifies state. Whether creating a session variable counts as "modifying
  disk, registry, or network state" is a judgement call, so it is recorded
  rather than assumed either way. The `-WhatIf:$false` currently passed to
  `New-Variable` is a side effect of that question and goes away if the
  answer is yes.

## Tooling gaps

- [x] **`Invoke-Pester.ps1` exited 0 on every run.** It never set
  `Run.PassThru`, so Pester returned `$null`, every count read as `0`, and a
  failing suite was reported as a pass. It also wrote errors without a
  non-zero exit when Pester was absent. Both fixed, and
  `Tests/PSToolkit.tests.ps1` now runs the real runner against deliberately
  failing, unparseable and module-less sandboxes to prove it. See the bug
  list below.

- [ ] **`Build-Module.ps1` builds anyway when Pester is absent.** It warns
  loudly, which satisfies half the rule, but still produces an unverified
  build. The guideline says to treat that warning as an error in any
  automated pipeline. Decide: hard-fail the build, or require an explicit
  opt-out switch such as `-SkipTests`. Needs a decision — see below.

- [ ] **`Build-Module.ps1` produces a module that is not self-contained.** It
  copies `Public\*.ps1`, `Private\*.ps1`, `Scripts\*.ps1` and the README.
  It does not copy `LICENSE` or `Tests\`. `LicenseUri` is a GitHub URL so
  it still resolves, but an installed copy carries no licence text and no
  way to run its own tests. Done when the output folder matches what
  `PSToolkit.psd1` claims to need.

- [ ] **`Build-Module.ps1` rewrites the checked-in manifest destructively.**
  `Update-ModuleManifest` reserialises the whole file: one run turned a
  37-line hand-written manifest into 128 lines of generated boilerplate,
  dropped the comments explaining *why* the export lists are explicit, and
  commented out `VariablesToExport = @()` - which `AGENTS.md` 1.6 requires
  to be an explicit array. So running a build leaves a dirty working tree
  and undoes a rule the repo is supposed to satisfy. There is a real
  trade-off, so this needs a decision rather than a guess. Writing the derived
  exports into the *copied* manifest instead of the source keeps the repo's
  manifest hand-owned and stops the churn, but loses the drift check: adding a
  function to `Public/` and forgetting the manifest would no longer show up as
  a `git diff` after a build. Options: apply exports to the output copy only;
  keep updating the source but re-apply the explicit empty arrays and comments
  afterwards; or drop the derivation and treat the manifest as hand-maintained.

- [ ] **The lint gate is `-Severity Error` only.** The repo has 0 errors and
  32 warnings. Most are Pester `BeforeAll` false positives
  (`PSUseDeclaredVarsMoreThanAssignments`), which are noise. Decide whether
  to fix the real ones and raise the gate, or record a baseline count that
  must not increase. Needs a decision.

- [x] **Markdown linting was documented but not gated.** `AGENTS.md` requires
  markdownlint-cli2 and the repo is clean under it, but nothing enforced it:
  `Tests/Quality.tests.ps1` only runs PSScriptAnalyzer, so a later edit could
  break the rules while the suite stayed green. Fixed by adding
  `.githooks/pre-commit`, which lints the staged Markdown, and pinning
  `.githooks/*` to LF in `.gitattributes` so the shebang survives the
  repository-wide `eol=crlf` rule. A missing linter fails the commit rather
  than skipping quietly, per 1.8. The hook is off by default on a fresh clone
  because `core.hooksPath` is local config, so the enable step is documented in
  `AGENTS.md` rather than assumed.

- [ ] **The pre-commit hook is advisory in practice and cannot be the only
  gate.** It covers staged Markdown on a machine where it is enabled, and it
  covers nothing else: a file edited without being staged, a commit made with
  `--no-verify`, a clone where `core.hooksPath` was never set, or CI. If the
  Markdown rules are to be a real gate rather than a convenience, they need to
  run in `Tests/Quality.tests.ps1` or in a CI step as well. The tool-absent
  case needs the same decision as above, except that here the honest default
  is failure, so the practical question is whether a developer without Node
  installed can run the suite at all.

## Deliberate behaviour to confirm or change

- [ ] **`Get-EmptyFolders` scans excluded directories; `Get-FolderStructure`
  prunes them.** Currently intentional and recorded in `AGENTS.md` 2.5.
  The difference is real: pruning is faster, but scanning still finds empty
  directories that live *inside* an excluded folder. Confirm which
  behaviour is wanted for `Get-EmptyFolders`, then either keep it and
  tighten the wording, or make both prune. Needs a decision.

- [ ] **`Get-FolderStructure.LegacyArgs` is a dead shim.** It swallows the
  old cmd.exe `tree` flags `/A` and `/F` and is deliberately undocumented
  and allowlisted in `Tests/PSToolkit.tests.ps1`. Retiring the parameter is
  a fair future change; the cost is breaking anyone still passing those
  flags. Needs a decision.

## Housekeeping

- [x] Default branch is `main`; `master` removed. Attribution is the
  `MisterSeajay` alias only.
- [x] MIT `LICENSE` added; all `PSData` URLs point at this repo and resolve.
- [x] All PowerShell files are UTF-8 with BOM; `.gitattributes` pins line
  endings.
- [x] Comment-based help completed for every public function, with
  `.LINK`, and guarded by a test in `Tests/PSToolkit.tests.ps1`.
- [x] `-Exclude` unified across both public functions to match
  `Get-ChildItem -Exclude`.
- [x] `Get-FolderStructure` split into a data function plus the `Format-Tree`
  renderer; output verified byte-for-byte against the old implementation.
- [x] `AGENTS.md` written and `CLAUDE.md` reduced to a pointer at it.

## Bugs found and fixed

Kept because each one was invisible until something forced it into the open,
and each is now covered by a test.

- **The test gate never failed anything.** `Invoke-Pester.ps1` did not set
  `Run.PassThru`, so Pester 6 returned `$null`; the failure total read as `0`
  and the runner printed "All tests passed" and exited 0 on a failing suite.
  Found because a new test failed and the runner still reported success. This
  means every earlier claim that the gate had been repaired was wrong: the
  failure-counting fix was real, but it was reading `$null`.
- `Build-Module.ps1` used `$ModuleRoot` before assigning it, so the build
  script failed on its first statement.
- The Pester gate probed with `Get-Module -ListAvailable`, which lists without
  loading, so `[PesterConfiguration]` never resolved and the gate was skipped
  while the build still reported success.
- Both test runners checked only `FailedCount`, missing
  `FailedContainersCount` and `FailedBlocksCount`, and did not exit non-zero.
- Two wrong last-sibling rules in `Format-Tree`: "the next node is shallower"
  breaks for a node with children, and "no later node shares my depth" breaks
  because nodes at equal depth in different subtrees are not siblings. Both
  are pinned by `Tests/Format-Tree.tests.ps1`.
- An empty `PSModulePath` does not disable module discovery, so the first
  version of the "Pester unavailable" test passed without ever reaching the
  branch it claimed to cover. It now points at a non-existent directory, and
  was found to hang the child process before being fixed.
