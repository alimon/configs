#!/usr/bin/python

import re
import sys

def read_dpkgfile(file):
    d = {}
    with open(file) as f:
        for line in f:
            line = " ".join(line.split())
            m = re.search('^ii (\S+) (\S+).*', line)
            if m:
                d[m.group(1)] = m.group(2)
    return d

def main():

    c = []
    r = []
    a = []

    d1 = read_dpkgfile(sys.argv[1])
    d2 = read_dpkgfile(sys.argv[2])

    for pkg in d1.keys():
        if pkg in d2:
            if d1[pkg] != d2[pkg]:
                c.append("%s from %s to %s" % (pkg, d1[pkg], d2[pkg]))

            del d2[pkg]
        else:
            r.append("%s (%s)" % (pkg, d1[pkg]))

    for pkg in d2.keys():
        a.append("%s (%s)" % (pkg, d2[pkg]))

    print("Added packages:")
    for line in sorted(a):
        print('\t'+line)
    print("")

    print("Changed packages:")
    for line in sorted(c):
        print('\t'+line)
    print("")

    print("Removed packages:")
    for line in sorted(r):
        print('\t'+line)


if __name__ == "__main__":
    main()
