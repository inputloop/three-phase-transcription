#!/bin/sh
# tests/tr-spec.sh -- a second reader for the three transcription phases (tr1qt, tr2sm, tr3rm),
#   written in POSIX sh + awk so it shares no code, language or parser with the tools it checks.
#   Copyright 2026 Corwin Brust <corwin@bru.st> and Contributors.  Authored by Mentat (for Corwin).
#   SPDX-License-Identifier: GPL-3.0-or-later OR LGPL-3.0-or-later
#
# usage: sh tests/tr-spec.sh SDIR QDIR...    check one real set of outputs
#        sh tests/tr-spec.sh --prove-red     build a fixture with the tools, check it green, then
#                                            plant each fault by hand and show this reader fire
# What it reads, by itself:
#   S1  every QUOTES.tsv row (key stem@start) appears in LINKS.tsv exactly once, and nothing else does
#   S2  every LINKS.tsv subject has its SUBJECTS.tsv row and its <slug>.md file
#   S3  every "[stem hh:mm:ss] words" line in a subject file or RESULT.md carries the exact words of
#       the QUOTES row whose start, written as hh:mm:ss by awk here, matches
#   S4  every RESULT.tsv key is a QUOTES key
# Exit 0 when all hold; 1 with one FAIL line per fault.
LC_ALL=C; export LC_ALL

check() {
  sd=$1; shift
  tmp=${TMPDIR:-/tmp}/trspec.$$; mkdir -p "$tmp"
  : > "$tmp/q"
  for q in "$@"; do
    stem=$(basename "$q")
    awk -F'\t' -v s="$stem" 'NF==4 { t=int($1); printf "%s@%s\t%s\t%02d:%02d:%02d\t%s\n", s, $1, s, t/3600, (t%3600)/60, t%60, $4 }' "$q/QUOTES.tsv" >> "$tmp/q"
  done
  fails=0
  # S1
  cut -f1 "$tmp/q" | sort > "$tmp/qk"
  cut -f1 "$sd/LINKS.tsv" | sort > "$tmp/lk"
  d=$(cut -f1 "$sd/LINKS.tsv" | sort | uniq -d | head -1)
  [ -n "$d" ] && { echo "FAIL S1 key linked twice: $d"; fails=$((fails+1)); }
  cmp -s "$tmp/qk" "$tmp/lk" || { echo "FAIL S1 LINKS.tsv keys differ from the QUOTES rows ($(wc -l < "$tmp/qk") quotes, $(wc -l < "$tmp/lk") links)"; fails=$((fails+1)); }
  # S2
  for s in $(cut -f2 "$sd/LINKS.tsv" | sort -u); do
    grep -q "^$s	" "$sd/SUBJECTS.tsv" || { echo "FAIL S2 $s has no SUBJECTS.tsv row"; fails=$((fails+1)); }
    [ -f "$sd/$s.md" ] || { echo "FAIL S2 $s.md missing"; fails=$((fails+1)); }
  done
  # S3
  for mf in "$sd"/*.md; do
    cout=$(awk -F'\t' -v FN="$(basename "$mf")" '
      FNR==NR { w[$2" "$3] = (($2" "$3) in w) ? w[$2" "$3] SUBSEP $4 : $4; next }
      { line=$0; sub(/^- /, "", line) }
      line ~ /^\[[^] ]+ [0-9][0-9]:[0-9][0-9]:[0-9][0-9]\] / {
        k=substr(line, 2, index(line, "]")-2); words=substr(line, index(line, "]")+2)
        if (!(k in w)) { print "FAIL S3 " FN ":" FNR " cites [" k "], no such quote"; bad++; next }
        m=split(w[k], alts, SUBSEP); ok=0
        for (i=1; i<=m; i++) if (alts[i]==words) ok=1
        if (!ok) { print "FAIL S3 " FN ":" FNR " words differ from [" k "]"; bad++ }
      }
      END { exit bad>0 }' "$tmp/q" "$mf")
    [ -n "$cout" ] && { echo "$cout"; fails=$((fails+$(echo "$cout" | wc -l))); }
  done
  # S4
  if [ -f "$sd/RESULT.tsv" ]; then
    for k in $(cut -f3 "$sd/RESULT.tsv"); do
      grep -q "^$k	" "$tmp/q" || { echo "FAIL S4 RESULT.tsv key $k is not a quote"; fails=$((fails+1)); }
    done
  fi
  rm -rf "$tmp"
  echo "tr-spec: $sd: $fails fault(s)"
  [ "$fails" -eq 0 ]
}

prove_red() {
  here=$(cd "$(dirname "$0")/.." && pwd); t=${TMPDIR:-/tmp}/trred.$$; mkdir -p "$t/rec"
  printf '0.00\t4.00\t00:00:00\twe agreed on the terms\n70.00\t74.00\t00:01:10\tbut not the fallback?\n3700.00\t3704.00\t01:01:40\tthe garden view\n' > "$t/rec/QUOTES.tsv"
  python3 "$here/bin/tr2sm" build "$t/rec" --out "$t/s" > /dev/null || { echo "tr2sm failed"; return 1; }
  python3 "$here/bin/tr3rm" build "$t/s" "$t/rec" > /dev/null || { echo "tr3rm failed"; return 1; }
  pass=0; n=0
  n=$((n+1)); check "$t/s" "$t/rec" > /dev/null && pass=$((pass+1))                         # clean reads clean
  cp -r "$t/s" "$t/a"; sed '1d' "$t/s/LINKS.tsv" > "$t/a/LINKS.tsv"
  n=$((n+1)); check "$t/a" "$t/rec" > /dev/null || pass=$((pass+1))                         # plant S1: a quote unlinked
  cp -r "$t/s" "$t/b"; f=$(ls "$t/b"/free-*.md | head -1); sed 's/the garden view/the garden VIEW/' "$f" > "$f.x" && mv "$f.x" "$f"
  n=$((n+1)); check "$t/b" "$t/rec" > /dev/null || pass=$((pass+1))                         # plant S3: words altered
  cp -r "$t/s" "$t/c"; echo "- [rec 00:09:09] nobody said this" >> "$t/c/RESULT.md"
  n=$((n+1)); check "$t/c" "$t/rec" > /dev/null || pass=$((pass+1))                         # plant S3: ghost time
  cp -r "$t/s" "$t/d"; printf 'PIN\tx\trec@9.99\tghost\n' >> "$t/d/RESULT.tsv"
  n=$((n+1)); check "$t/d" "$t/rec" > /dev/null || pass=$((pass+1))                         # plant S4
  cp -r "$t/s" "$t/e"; rm "$t/e/$(cut -f2 "$t/s/LINKS.tsv" | head -1).md"
  n=$((n+1)); check "$t/e" "$t/rec" > /dev/null || pass=$((pass+1))                         # plant S2
  rm -rf "$t"
  echo "tr-spec --prove-red: $pass/$n planted cases read as planted"
  [ "$pass" -eq "$n" ]
}

case "$1" in
  --prove-red) prove_red ;;
  ""|-h|--help) sed -n '2,20p' "$0" ;;
  *) check "$@" ;;
esac
