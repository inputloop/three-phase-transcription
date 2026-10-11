#!/bin/sh
# sync.sh -- a repo that is a projection of part of a C4 tree, and back.  PATHS (beside this file) lists
#   the C4-relative files and folders the repo carries, one per line; '#' starts a comment.
#   Copyright 2026 Corwin Brust <corwin@bru.st> and Contributors.
#   SPDX-License-Identifier: GPL-3.0-or-later OR LGPL-3.0-or-later
# usage, from the top of the repo:
#   sh sync.sh from C4_ROOT     bring the listed paths in from a C4 tree (the repo's files are replaced)
#   sh sync.sh into C4_ROOT     put the listed paths back into a C4 tree (unpack as part of C4)
#   sh sync.sh diff C4_ROOT     say which listed files differ between the two, in words; exit 1 if any
#   sh sync.sh --prove-red      planted cases the three commands must handle
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)

paths() { sed 's/#.*//; s/[ \t]*$//' "$1" | grep -v '^$'; }
files_under() { ( cd "$1" && for p in $(paths "$2"); do [ -e "$p" ] && find "$p" -type f; done ) | LC_ALL=C sort -u; }
copy() {   # copy SRC DST LIST: every listed path, from SRC to DST
  for p in $(paths "$3"); do
    [ -e "$1/$p" ] || { echo "sync: $p is not in $1" >&2; return 1; }
    mkdir -p "$2/$(dirname "$p")"; rm -rf "${2:?}/$p"; cp -R "$1/$p" "$2/$p"
  done
}
differ() {   # differ A B LIST: print one line per differing file
  { files_under "$1" "$3"; files_under "$2" "$3"; } | LC_ALL=C sort -u | while IFS= read -r f; do
    if [ ! -f "$1/$f" ]; then echo "- $f is only in $2"
    elif [ ! -f "$2/$f" ]; then echo "- $f is only in $1"
    elif ! cmp -s "$1/$f" "$2/$f"; then echo "- $f differs"; fi
  done
}

case "${1:-}" in
from) copy "$2" "$HERE" "$HERE/PATHS"; echo "sync: $(files_under "$HERE" "$HERE/PATHS" | wc -l) file(s) in from $2" ;;
into) copy "$HERE" "$2" "$HERE/PATHS"; echo "sync: $(files_under "$HERE" "$HERE/PATHS" | wc -l) file(s) out to $2" ;;
diff) d=$(differ "$HERE" "$2" "$HERE/PATHS")
      if [ -n "$d" ]; then echo "$d"; exit 1; else echo "sync: in step with $2"; fi ;;
--prove-red)
  t=$(mktemp -d); fails=0; n=0
  mkdir -p "$t/c4/bin" "$t/c4/serve/pages" "$t/repo"; echo a > "$t/c4/bin/x"; echo b > "$t/c4/serve/pages/p.html"
  printf 'bin/x   # a tool\n\nserve\n' > "$t/repo/PATHS"; cp "$0" "$t/repo/sync.sh"
  n=$((n+1)); sh "$t/repo/sync.sh" from "$t/c4" >/dev/null
  if [ -f "$t/repo/serve/pages/p.html" ] && [ -f "$t/repo/bin/x" ]; then echo "caught: S1 from brings files and folders, comments ignored"; else echo "MISSED: S1"; fails=$((fails+1)); fi
  echo changed > "$t/repo/bin/x"
  n=$((n+1)); if sh "$t/repo/sync.sh" diff "$t/c4" | grep -q 'bin/x differs'; then echo "caught: S2 diff names a changed file"; else echo "MISSED: S2"; fails=$((fails+1)); fi
  echo c > "$t/c4/serve/stale.js"
  n=$((n+1)); if sh "$t/repo/sync.sh" diff "$t/c4" | grep -q 'serve/stale.js is only in'; then echo "caught: S3 diff names a file only one side has"; else echo "MISSED: S3"; fails=$((fails+1)); fi
  sh "$t/repo/sync.sh" into "$t/c4" >/dev/null
  n=$((n+1)); if [ "$(cat "$t/c4/bin/x")" = changed ] && [ ! -e "$t/c4/serve/stale.js" ] && sh "$t/repo/sync.sh" diff "$t/c4" >/dev/null; then echo "caught: S4 into makes the tree match, folders replaced whole"; else echo "MISSED: S4"; fails=$((fails+1)); fi
  rm -rf "$t"; echo "sync prove-red: $((n-fails))/$n planted cases caught"; [ "$fails" = 0 ] ;;
*) sed -n '2,11p' "$0"; exit 2 ;;
esac
