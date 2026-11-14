#!/usr/bin/env bash
# package_release.sh - build the downloadable packages of a release from what is already in dist/.
#
# Usage:  bash tools/package_release.sh -v <version> [-a "64 32"] [-o <folder>] [-f]
#   -v  release version, e.g. v0.1.0-alpha.1 (required; used in the file names)
#   -a  Linux architectures to package (default "64"; add 32 if you built it)
#   -o  output folder (default release/<version>)
#   -f  package even if the git working tree has uncommitted changes
#
# Run it from the repository root, on Linux, WSL or Git Bash, AFTER building and testing:
#   Linux   : bash build_all.sh -A -T
#             (gives dist/abcd/linux64/ansi, ansi/bigisis, utf8, utf8/bigisis)
#   Windows : build_windows_all_bcc55.bat > build_windows_all.log 2>&1
#             (gives dist\abcd\windows32\ansi, ansi\bigisis, utf8, utf8\bigisis)
# Whatever is missing is skipped with a warning; at least one package must come out.
#
# Output (in release/<version>/):
#   xiscore-<version>-linux64-abcd.tar.gz     cgi-bin/{ansi,ansi/bigisis,utf8,utf8/bigisis}, same layout as ABCD
#   xiscore-<version>-windows32-abcd.zip      the same for Windows (Borland C++ 5.5, 32-bit)
#   SHA256SUMS.txt                          checksums of the packages
# Every package also carries LICENSE, README.md, INSTALL.txt and BUILDINFO.txt (commit, date, banners,
# and the SHA-256 of every binary inside).

set -u
export LC_ALL=C
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

VER=""; ARCHS="64"; OUT=""; FORCE=0
while getopts "v:a:o:fh" o; do
  case $o in
    v) VER=$OPTARG;; a) ARCHS=$OPTARG;; o) OUT=$OPTARG;; f) FORCE=1;;
    *) sed -n '2,24p' "$0"; exit 1;;
  esac
done
[ -n "$VER" ] || { sed -n '2,24p' "$0"; echo; echo "ERROR: -v <version> is required"; exit 1; }
case $VER in *[!A-Za-z0-9._-]*) echo "ERROR: version may only contain letters, digits, '.', '_' and '-'"; exit 1;; esac
[ -n "$OUT" ] || OUT="release/$VER"

# ---- source state -----------------------------------------------------------------------------
COMMIT=unknown; DESCR=unknown
if git rev-parse --git-dir >/dev/null 2>&1; then
  COMMIT=$(git rev-parse HEAD)
  DESCR=$(git describe --tags --always --dirty 2>/dev/null || echo "$COMMIT")
  if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    if [ $FORCE = 1 ]; then echo "WARNING: uncommitted changes; the packages will not match commit $COMMIT"
    else echo "ERROR: the working tree has uncommitted changes. Commit them (the binaries must match a commit) or use -f."; exit 1; fi
  fi
else
  echo "WARNING: not a git repository; BUILDINFO.txt will not name a commit"
fi

sha() { if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }
mkdir -p "$OUT" || exit 1
STAGE=$(mktemp -d) || exit 1
trap 'rm -rf "$STAGE"' EXIT
MADE=""

# ---- text files that go into every package --------------------------------------------------
common_files() {  # $1 = package folder, $2 = platform text
  local d=$1
  cp LICENSE README.md "$d/"
  cat > "$d/INSTALL.txt" <<EOF
XisCore Engine $VER - $2 - binaries for ABCD
=========================================================================

THIS IS A TEST RELEASE. Do not replace the binaries of a production ABCD without testing first.

The folder cgi-bin/ has the same layout as ABCD's cgi-bin:

  cgi-bin/ansi/            isis1660, ANSI    (ABCD's administrative databases: banner .../M/32767/16/60/...)
  cgi-bin/ansi/bigisis/    bigisis,  ANSI    (ABCD's large databases:          banner .../F/M/1048576/16/256/...)
  cgi-bin/utf8/            isis1660, UTF-8
  cgi-bin/utf8/bigisis/    bigisis,  UTF-8

wxis1660 and wxisnonuni are copies (of ansi/wxis and of ansi/bigisis/wxis) kept because
ABCD's cgi-bin has files with those names.

To try it in ABCD:
  1. Make a backup copy of ABCD's cgi-bin folder (and of the databases you will test with).
  2. Copy the contents of this cgi-bin/ over ABCD's cgi-bin.
  3. Check the banner:  mx   (first line, e.g. "XisCore Engine v0.1.0/.../M/32767/16/60/I/...")
  4. Test on COPIES of your databases: open, search, browse, edit and save records, rebuild an index.
  5. To go back, restore the backup of step 1.

A database must be read and written by a binary of the same variant (isis1660 or bigisis).
Exact limits and the compatibility table: _docs/LIMITS.md in the repository.

Report problems at https://github.com/ABCD-DEVCOM/CISIS_UTF8/issues with: the banner of mx,
the operating system, what you did, what you expected and what happened.

BUILDINFO.txt lists the commit these binaries were built from and the SHA-256 of every file.
EOF
}

buildinfo() {  # $1 = package folder, $2 = platform text, $3 = compiler text
  local d=$1 f b
  {
    echo "XisCore Engine $VER - $2"
    echo "source commit : $COMMIT ($DESCR)"
    echo "packaged on   : $(date -u '+%Y-%m-%d %H:%M UTC')"
    echo "compiler      : $3"
    echo
    echo "banners (mx, first line):"
    for f in "$d"/cgi-bin/ansi/mx* "$d"/cgi-bin/ansi/bigisis/mx* "$d"/cgi-bin/utf8/mx* "$d"/cgi-bin/utf8/bigisis/mx*; do
      [ -f "$f" ] || continue
      case $(basename "$f") in mx|mx.exe) ;; *) continue;; esac
      b=$(timeout 10 "$f" 2>&1 </dev/null | head -1 | tr -d '\r')
      case $b in XisCore*|CISIS*) ;; *) b="(could not be run here)";; esac
      echo "  ${f#$d/}: $b"
    done
    echo
    echo "SHA-256 of every file:"
    (cd "$d" && find cgi-bin -type f | sort | while read -r f; do sha "$f"; done)
  } > "$d/BUILDINFO.txt"
}

# ---- Linux: dist/abcd/linux<arch> has ABCD's layout (made by build_all.sh -A) -----------------------
for A in $ARCHS; do
  SRC="dist/abcd/linux$A"; NAME="xiscore-$VER-linux$A-abcd"; P="$STAGE/$NAME"
  if [ ! -x "$SRC/ansi/mx" ] && [ ! -x "$SRC/utf8/mx" ]; then
    echo "WARNING: $SRC/{ansi,utf8}/mx not found: Linux $A-bit package skipped (build it with: bash build_all.sh -A -a $A -T)"; continue
  fi
  mkdir -p "$P/cgi-bin" && cp -rp "$SRC/." "$P/cgi-bin/"
  for d in ansi ansi/bigisis utf8 utf8/bigisis; do
    [ -x "$P/cgi-bin/$d/mx" ] || echo "WARNING: $SRC/$d/mx not found: cgi-bin/$d will be missing from the Linux $A-bit package"
  done
  common_files "$P" "Linux $A-bit"
  buildinfo "$P" "Linux $A-bit" "$(gcc --version 2>/dev/null | head -1)"
  tar -C "$STAGE" -czf "$OUT/$NAME.tar.gz" "$NAME" || exit 1
  echo "OK  $OUT/$NAME.tar.gz  ($(find "$P/cgi-bin" -type f | wc -l) files)"
  MADE="$MADE $NAME.tar.gz"
done

# ---- Windows: dist/abcd/windows32 already has ABCD's layout -------------------------------------
SRC="dist/abcd/windows32"; NAME="xiscore-$VER-windows32-abcd"; P="$STAGE/$NAME"
if [ -f "$SRC/utf8/mx.exe" ] || [ -f "$SRC/ansi/mx.exe" ]; then
  mkdir -p "$P/cgi-bin"
  (cd "$SRC" && find . -type f -name '*.exe' | while read -r f; do mkdir -p "$P/cgi-bin/$(dirname "$f")"; cp -p "$f" "$P/cgi-bin/$f"; done)
  for d in ansi ansi/bigisis utf8 utf8/bigisis; do
    [ -f "$P/cgi-bin/$d/mx.exe" ] || echo "WARNING: $SRC/$d/mx.exe not found: cgi-bin/$d will be missing from the Windows package"
  done
  common_files "$P" "Windows 32-bit"
  for f in INSTALL.txt; do sed -i 's/$/\r/' "$P/$f"; done
  buildinfo "$P" "Windows 32-bit" "Borland C++ 5.5.1 (build_windows_all_bcc55.bat)"
  sed -i 's/$/\r/' "$P/BUILDINFO.txt"
  rm -f "$OUT/$NAME.zip"
  if command -v zip >/dev/null; then (cd "$STAGE" && zip -qr -X "$ROOT/$OUT/$NAME.zip" "$NAME") || exit 1
  else python3 - "$STAGE" "$NAME" "$ROOT/$OUT/$NAME.zip" <<'PY' || exit 1
import os, sys, zipfile
stage, name, out = sys.argv[1:4]
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for dp, dn, fn in os.walk(os.path.join(stage, name)):
        dn.sort()
        for f in sorted(fn):
            full = os.path.join(dp, f)
            z.write(full, os.path.relpath(full, stage))
PY
  fi
  echo "OK  $OUT/$NAME.zip  ($(find "$P/cgi-bin" -type f | wc -l) files)"
  MADE="$MADE $NAME.zip"
else
  echo "WARNING: $SRC/{ansi,utf8}/mx.exe not found: Windows package skipped (build it on Windows with build_windows_all_bcc55.bat)"
fi

# ---- checksums ----------------------------------------------------------------------------------
[ -n "$MADE" ] || { echo "ERROR: no package was produced"; exit 1; }
(cd "$OUT" && sha $MADE > SHA256SUMS.txt) || exit 1
echo "OK  $OUT/SHA256SUMS.txt"
echo
echo "Next: create the tag ($VER) on commit $COMMIT, open a GitHub release marked as pre-release,"
echo "paste the release notes and attach the files of $OUT/."
