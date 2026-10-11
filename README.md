# three-phase transcription

Recorded talk in three layers, each citing the one below: quotes by time (`tr1qt`), subjects (`tr2sm`), and the result, with each seam and the pin that holds it (`tr3rm`). `tr2vs` holds a subject layer against another reader's findings, and `tests/tr-spec.sh` re-reads a set in sh and awk.

`transcripts/RECIPE.org` says how to make a set, check it and rebuild. The sets themselves stay where they were recorded; only the tools travel.

This repo carries the paths in `PATHS`, and `sync.sh` moves them both ways:

```
sh sync.sh diff /f/claude/c4     # what differs, in words
sh sync.sh into /f/claude/c4     # unpack into a C4 tree
sh sync.sh from /f/claude/c4     # rebuild this repo from one
```

Free software: GPL-3.0-or-later OR LGPL-3.0-or-later, as each file says (`COPYING`, `COPYING.LESSER`).
