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
        if 'Parent directory' in tr.text or 'last.commit' in tr.text or '-lava-bisect-' in tr.text:
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
    version = last_build.contents[0].text[0:-1] # remove last / char

    return (image_url, dt_url, modules_url, version)


def get_ramdisk_rootfs_url(url, rootfs_url):
    f = urllib2.urlopen('https://ci.linaro.org/job/lt-qcom-openembedded-rpb-rocko/lastSuccessfulBuild/buildNumber')
    last_build = int(f.read())

    url = '%s/%d/rpb' % (url, last_build)
    f = urllib2.urlopen(url)
    page = f.read()
    base_url_p = urlparse.urlparse(url)
    base_url = "%s://%s" % (base_url_p.scheme, base_url_p.netloc)

    ramdisk_rex = re.compile('initramfs-bootrr-image-.*\.rootfs\.cpio\.gz$')
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

    return (ramdisk_url, rootfs_url)


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
                                           'arm64/defconfig/')
    machines = os.environ.get('MACHINES', 'dragonboard410c dragonboard820c sdm845_mtp').split()

    ramdisk_base_url = os.environ.get('RAMDISK_BASE_URL',
                                      'https://snapshots.linaro.org/96boards/%s/linaro/openembedded/rocko')
    rootfs_base_url = os.environ.get('ROOTFS_BASE_URL',
                                      'https://snapshots.linaro.org/96boards/%s/linaro/openembedded/rocko')
    builds_url = os.environ.get('BUILDS_URL',
                                'https://snapshots.linaro.org/96boards/%s/linaro/linux-integration/')

    image_url = None
    modules_url = None
    version = None
    for m in machines:
        if m == 'dragonboard410c':
            kernel_ci_dt_file = 'dtbs/qcom/apq8016-sbc.dtb'
            ramdisk_url = ramdisk_base_url % m
            rootfs_url = rootfs_base_url % m
        elif m == 'dragonboard820c':
            kernel_ci_dt_file = 'dtbs/qcom/apq8096-db820c.dtb'
            ramdisk_url = ramdisk_base_url % m
            rootfs_url = rootfs_base_url % m
        elif m == 'sdm845_mtp':
            kernel_ci_dt_file = 'dtbs/qcom/sdm845-mtp.dtb'
            ramdisk_url = ramdisk_base_url % 'dragonboard410c' # XXX: Use ramdisk from db410c for now
            rootfs_url = rootfs_base_url % 'dragonboard410c'
        else:
            sys.exit(2)

        (image_url, dt_url, modules_url, version) = get_kernel_ci_build(kernel_ci_base_url,
                                                                        kernel_ci_arch_config, kernel_ci_dt_file)

        print("KERNEL_DT_URL_%s=%s" % (m, dt_url))
        validate_url(dt_url)

        (ramdisk_url, rootfs_url) = get_ramdisk_rootfs_url(ramdisk_url, rootfs_url)
        print('RAMDISK_URL_%s=%s' % (m, ramdisk_url))
        validate_url(ramdisk_url)
        print('ROOTFS_URL_%s=%s' % (m, rootfs_url))
        validate_url(rootfs_url)

        try:
            validate_if_already_built((builds_url % m), (image_url, dt_url, modules_url,
                                      ramdisk_url, rootfs_url))
        except urllib2.HTTPError as e:
            # 404 can happen when no previous build exists
            if e.code != 404:
                raise

    print("KERNEL_IMAGE_URL=%s" % image_url)
    validate_url(image_url)
    print("KERNEL_MODULES_URL=%s" % modules_url)
    validate_url(modules_url)
    print("KERNEL_VERSION=%s" % version)


if __name__ == '__main__':
    try:
        ret = main()
    except Exception:
        ret = 1
        import traceback
        traceback.print_exc()
    sys.exit(ret)
