#!/usr/bin/env python

import sys
import os
import errno
import urllib2
import md5

TRACK_URLS_DIR = '.url_change'

try:
    os.makedirs(TRACK_URLS_DIR)
except OSError as err:
    if err.errno != errno.EEXIST:
        raise

release_base_url = os.getenv('RELEASE_BASE_URL', 'http://snapshots.linaro.org/member-builds/qcomlt/kernel')
release_names = os.getenv('RELEASE_NAMES', 'release_qcomlt-4.14').split()

release_name = ''
release_url = ''
found = False

for release_name in release_names:
    release_url = "%s/%s" % (release_base_url, release_name)

    cksum_file = os.path.join(TRACK_URLS_DIR, release_name)
    checksums = []
    try:
        f = open(cksum_file, 'r')
        checksums = f.read().split()
    except IOError as err:
        if err.errno != errno.ENOENT:
            raise

    f = urllib2.urlopen(release_url)
    page = f.read()

    cksum = md5.new(page).hexdigest()
    if cksum not in checksums:
        with open(cksum_file, 'a+') as f:
            f.write("%s\n" % cksum)
        found = True
        break

if found:
    print("RELEASE_NAME=%s" % release_name)
    print("RELEASE_URL=%s" % release_url)
    sys.exit(0)

sys.exit(1)
