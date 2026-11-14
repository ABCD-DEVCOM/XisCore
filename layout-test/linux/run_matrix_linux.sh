#!/usr/bin/env bash
# run_matrix_linux.sh - read every example database with every mx binary and report.
#
# Usage:  bash run_matrix_linux.sh  WWW_DIR  MX_BIN [MX_BIN ...]
#   WWW_DIR = the "www" folder of the ABCD repository (contains bases-examples_Linux and bases-examples_Windows)
#   MX_BIN  = one or more mx executables to test, e.g. the official Linux build and the test build
#
# The repository is never written to: each database is copied to a temporary folder first.
# Output: a table on screen and results/linux_matrix.txt
#   verdict OK      = the program printed records (mfn=...) and no fatal error
#   verdict FATAL  = the program stopped with a fatal error (the message is shown)

set -u
WWW=${1:?usage: run_matrix_linux.sh WWW_DIR MX_BIN [MX_BIN ...]}; shift
[ $# -ge 1 ] || { echo "usage: run_matrix_linux.sh WWW_DIR MX_BIN [MX_BIN ...]"; exit 1; }
HERE=$(cd "$(dirname "$0")/.." && pwd)
RES="$HERE/results"; mkdir -p "$RES"
REPORT="$RES/linux_matrix.txt"
WORK=$(mktemp -d /tmp/matrix.XXXXXX)
: > "$REPORT"

printf '%-34s %-10s %-22s %-8s %s\n' "binary" "source" "database" "verdict" "detail" | tee -a "$REPORT"
for SRC in bases-examples_Linux bases-examples_Windows; do
  [ -d "$WWW/$SRC" ] || { echo "missing: $WWW/$SRC"; continue; }
  # every database is a folder <db>/data/<db>.mst
  for MST in "$WWW/$SRC"/*/data/*.mst; do
    [ -f "$MST" ] || continue
    DATA=$(dirname "$MST"); DB=$(basename "$MST" .mst); DBDIR=$(dirname "$DATA")
    for BIN in "$@"; do
      BN=$(basename "$(dirname "$(readlink -f "$BIN")")")/$(basename "$BIN")
      TMPDATA="$WORK/$SRC/$(basename "$DBDIR")/data"
      rm -rf "$WORK/$SRC/$(basename "$DBDIR")"; mkdir -p "$TMPDATA"; cp -r "$DATA"/. "$TMPDATA"/
      OUT=$(cd "$TMPDATA" && timeout 120 "$(readlink -f "$BIN")" "$DB" "" "" </dev/null 2>&1)
      N=$(printf '%s\n' "$OUT" | grep -c 'mfn=')
      FAT=$(printf '%s\n' "$OUT" | grep -m1 'fatal' | tr -s ' ')
      if [ -n "$FAT" ]; then V=FATAL; D="$FAT"
      elif [ "$N" -gt 0 ]; then V=OK; D="$N records"
      else V=EMPTY; D="no records and no message"; fi
      printf '%-34s %-10s %-22s %-8s %s\n' "$BN" "${SRC#bases-examples_}" "$DB" "$V" "$D" | tee -a "$REPORT"
    done
  done
done
echo; echo "report: $REPORT"
echo "work dir (temporary copies, can be deleted): $WORK"
