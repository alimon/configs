#!/usr/bin/env python

import sys
import urllib2
import urlparse
import re

from bs4 import BeautifulSoup, SoupStrainer

def validate_url(url):
    urllib2.urlopen(url)

def main(url='https://snapshots.linaro.org/member-builds/qcomlt/testimages/arm64/',
         job_url='https://ci.linaro.org/job/lt-qcom-linux-testimages/',
         output='output.log'):

    f = urllib2.urlopen(job_url + "lastSuccessfulBuild/buildNumber")
    last_build = int(f.read())

    url = '%s/%d/' % (url, last_build)
    f = urllib2.urlopen(url)
    page = f.read()
    base_url_p = urlparse.urlparse(url)
    base_url = "%s://%s" % (base_url_p.scheme, base_url_p.netloc)

    ramdisk_rex = re.compile('initramfs-test-image-.*\.rootfs\.cpio\.gz$')
    ramdisk_url = ''
    soup = BeautifulSoup(page, "html.parser", parse_only=SoupStrainer("a"))
    for line in soup.find_all('a', href=True):
        s = ramdisk_rex.search(line['href'])
        if s:
            ramdisk_url = base_url + line['href']
            break

    rootfs_rex = re.compile('rpb-console-image-test-.*\.rootfs\.img\.gz$')
    rootfs_url = ''
    soup = BeautifulSoup(page, "html.parser", parse_only=SoupStrainer("a"))
    for line in soup.find_all('a', href=True):
        s = rootfs_rex.search(line['href'])
        if s:
            rootfs_url = base_url + line['href']
            break

    validate_url(ramdisk_url)
    validate_url(rootfs_url)

    print('Writting output to %s' % output)
    print('RAMDISK_URL=%s' % ramdisk_url)
    print('ROOTFS_URL=%s' % rootfs_url)

    with open(output, 'w') as f:
        f.write("RAMDISK_URL=" + ramdisk_url + '\n')
        f.write("ROOTFS_URL=" + rootfs_url + '\n')

if __name__ == "__main__":
    main(*sys.argv[1:])
