# TODO

Working list for PSToolkit. Items persist between sessions; check this file at
the start of a session and update it as things land.

Rules for this file:

- Tick a box only when the item is verified, not when the code compiles.
- Record the reason for a deliberate non-action, so it is not re-litigated.
- Add a new item the moment something is deferred rather than dropped.

Guidance for the project lives in `AGENTS.md`; cmdlet detail lives in
`Get-Help`. Neither duplicates what is tracked here.

## Documentation

- [ ] **Rewrite the README.** It is still the original two lines, so the repo
      has six exported commands, an MIT licence and almost no documentation.
      Per `AGENTS.md` 1.4 it covers the project, installation, usage and
      development requirements, and points at `Get-Help` for parameter
      detail. Done when a reader can install the module and run their first
      command from the README alone.

## Tooling gaps

- [ ] **`Invoke-Pester.ps1` exits 0 when Pester is absent.** It calls
      `Write-Error` and returns, but never `exit 1`, so a CI job reads a
      skipped suite as a pass. This is the exact failure `AGENTS.md` 1.8 warns
      about: "do not gate on a check that can be skipped silently." Done when
      a missing Pester produces a non-zero exit code, and there is a test
      proving it.

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

- [ ] **The lint gate is `-Severity Error` only.** The repo has 0 errors and
      32 warnings. Most are Pester `BeforeAll` false positives
      (`PSUseDeclaredVarsMoreThanAssignments`), which are noise. Decide whether
      to fix the real ones and raise the gate, or record a baseline count that
      must not increase. Needs a decision.

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
