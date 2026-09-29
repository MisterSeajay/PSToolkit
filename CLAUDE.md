# Claude Code

@AGENTS.md

Project instructions live in `AGENTS.md`, which is the canonical document for
every tool. Claude Code reads it through the `@AGENTS.md` import above, so there
is nothing to add here.

If you make a change that would mislead a future contributor — a rule, a trap, a
convention — put it in the appropriate section of `AGENTS.md` rather than here.
Section 1 is project-agnostic and is intended to be copied into other
repositories; Section 2 is specific to this one.

Repository-specific traps belong in `AGENTS.md` 2.2, not in a separate file. An
earlier `Powershell_2.md` held them and had to be folded back in, because a
cross-reference that points at a file nobody opens is not a cross-reference.
The README is for readers of the module; `TODO.md` is for deferred work.
