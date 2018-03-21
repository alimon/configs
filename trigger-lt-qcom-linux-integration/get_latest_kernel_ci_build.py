#!/usr/bin/env python

import sys
import os
import urllib2
import urlparse
import re
import dateutil.parser

from bs4 import BeautifulSoup, SoupStrainer


def get_kernel_ci_build(url, arch_config, dt_file):
    f = urllib2.urlopen(url)
    page = f.read()
    soup = BeautifulSoup(page, "html.parser")

    last_build = -1
    for tr in soup.select('table > tbody > tr'):
        if 'Parent directory' in tr.text or 'last.commit' in tr.text:
            continue

        if last_build == -1:
            last_build = tr
        elif dateutil.parser.parse(tr.contents[2].text) > \
                dateutil.parser.parse(last_build.contents[2].text):
            last_build = tr

    url = url + last_build.contents[0].text + arch_config

    image_url = url + 'Image'
    dt_url = url + dt_file
    modules_url = url + 'modules.tar.xz'

    return (image_url, dt_url, modules_url)


def get_ramdisk_url(url):
    f = urllib2.urlopen(url)
    page = f.read()

    base_url_p = urlparse.urlparse(url)
    base_url = "%s://%s" % (base_url_p.scheme, base_url_p.netloc)
    rex = re.compile('initramfs-bootrr-image-.*\.rootfs\.cpio\.gz$')

    ramdisk_url = ''
    soup = BeautifulSoup(page, "html.parser", parse_only=SoupStrainer("a"))
    for line in soup.find_all('a', href=True):
        s = rex.search(line['href'])
        if s:
            ramdisk_url = base_url + line['href']
            break

    return ramdisk_url


def validate_url(url):
    request = urllib2.Request(url)
    request.get_method = lambda: 'HEAD'
    urllib2.urlopen(request)


def validate_if_already_built(url, artifacts_urls):
    f = urllib2.urlopen(url)
    page = f.read()

    max_search = 8
    search_count = 0
    soup = BeautifulSoup(page, "html.parser")
    for tr in soup.select('table > tr'):
        if 'Parent Directory' in tr.text or 'latest' in tr.text:
            continue

        build_url = url + tr.contents[3].text.strip().rstrip()
        f = urllib2.urlopen(build_url)
        build_page = f.read()

        if all(u in build_page for u in artifacts_urls):
            print("INFO: Build exists %s in URL: %s" %
                  (str(artifacts_urls), build_url))
            sys.exit(1)

        search_count = search_count + 1
        if search_count > max_search:
            break


def main():
    kernel_ci_base_url = os.environ.get('KERNEL_CI_BASE_URL',
                                        'https://storage.kernelci.org/qcom-lt/integration-linux-qcomlt/')
    kernel_ci_arch_config = os.environ.get('KERNEL_CI_ARCH_CONFIG',
                                           'arm64/defconfig+CONFIG_CPU_BIG_ENDIAN=y/')
    kernel_ci_dt_file = os.environ.get('KERNEL_CI_DT_FILE',
                                       'dtbs/qcom/apq8016-sbc.dtb')
    ramdisk_base_url = os.environ.get('RAMDISK_BASE_URL',
                                      'https://snapshots.linaro.org/96boards/dragonboard410c/linaro/openembedded/rocko/latest/rpb/')
    builds_url = os.environ.get('BUILDS_URL',
                                'https://snapshots.linaro.org/96boards/dragonboard410c/linaro/linux-integration/')

    (image_url, dt_url, modules_url) = get_kernel_ci_build(kernel_ci_base_url,
                                                           kernel_ci_arch_config, kernel_ci_dt_file)
    print("KERNEL_IMAGE_URL=%s" % image_url)
    validate_url(image_url)
    print("KERNEL_DT_URL=%s" % dt_url)
    validate_url(dt_url)
    print("KERNEL_MODULES_URL=%s" % modules_url)
    validate_url(modules_url)

    ramdisk_url = get_ramdisk_url(ramdisk_base_url)
    print('ROOTFS_URL=%s' % ramdisk_url)
    validate_url(ramdisk_url)

    validate_if_already_built(builds_url, (image_url, dt_url, modules_url,
                              ramdisk_url))


if __name__ == '__main__':
    try:
        ret = main()
    except Exception:
        ret = 1
        import traceback
        traceback.print_exc()
    sys.exit(ret)
