# three-phase transcription

Recorded talk, in three layers that each cite the one below: quotes by time, subjects drawn from the quotes, and a result that names each seam and the pin that holds it, or says it is still open. Every sentence in a result can be followed back to the second it was said.

The tools are `tr1qt` (quotes), `tr2sm` (subjects) and `tr3rm` (the result); `tr2vs` holds a subject layer against another reader's findings, and `tests/tr-spec.sh` re-reads a set in sh and awk. `transcripts/RECIPE.org` says how to make a set, check it and rebuild. The sets themselves stay where they were recorded; only the tools travel. The repo's own path so far: a recipe, a recipe that writes files, goes both ways, a licence (11 files, last changed 2026-10-11).

Anything here that can be checked is checked twice, by two readers written in different languages from the same rules. Where they agree, the rules were clear enough to say twice. Where they differ, one of them found something the other missed, and that finding is written down before anything is fixed.

This repo carries the paths in `PATHS`, and `sync.sh` moves them both ways:

```
sh sync.sh diff /f/claude/c4     # what differs, in words
sh sync.sh into /f/claude/c4     # unpack into a C4 tree
sh sync.sh from /f/claude/c4     # rebuild this repo from one
```

Code is free software: GPL-3.0-or-later, or LGPL-3.0-or-later where a file says so. The prose is CC-BY-SA-4.0. Where a persona wrote something, it wrote for Corwin Brust, who holds the rights: the persona is the writer and never the rights-holder.

<!-- written by bin/rd4me from README.md.in and k/prose/ATOMS.org; edit those, not this -->
