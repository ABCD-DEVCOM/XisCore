#!/usr/bin/env python3
"""add_a2.py - adds ' -a2' (Borland struct alignment) to the COMMON and PLAT lines of the
Windows build generators/scripts. Finds the lines by content, not by line number.
Usage (from the repository root):  python3 add_a2.py FILE [FILE ...]
Safe to run twice: lines that already end in -a2 are left alone."""
import re, sys
# a COMMON/PLAT line is recognised by its last flag; that is the only place we append
PAT = re.compile(rb'^(set (?:COMMON|PLAT)=.*-D(?:INCPRECX|PCREADLINUX)=\d)(\r?)$', re.M)
for f in sys.argv[1:]:
    raw = open(f, 'rb').read()
    new, n = PAT.subn(rb'\1 -a2\2', raw)
    already = len(re.findall(rb'^set (?:COMMON|PLAT)=.*-a2\r?$', raw, re.M))
    if n == 0:
        print(f + ': no COMMON/PLAT line found (already done, or different file)' if already else f + ': NOTHING CHANGED, check the file')
        continue
    open(f, 'wb').write(new)
    print(f + ': added -a2 to %d line(s)' % n)
