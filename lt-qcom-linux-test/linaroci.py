#!/usr/bin/env python

import sys
import os
import urllib2
import urlparse
import re
import dateutil.parser

from bs4 import BeautifulSoup, SoupStrainer

def _find_last_build_in_linaro_ci(url):
    last_build = -1
    rex = re.compile('(?P<last_build>\d+)')
    f = urllib2.urlopen(url)
    page = f.read()
    soup = BeautifulSoup(page, "html.parser")
    div = soup.find(id="content")
    latest_found = False
    for tr in div.select('table > tr'):
        if latest_found:
            m = rex.search(tr.text)
            if m:
                last_build = int(m.group('last_build'))
                break
        if 'latest' in tr.text:
            latest_found = True

    return last_build


def get_linaro_ci_build(url):
    last_build = _find_last_build_in_linaro_ci(url)
    if last_build == -1:
        print('ERROR: Unable to find last build (%s)' % url)
        sys.exit(1)

    url = '%s/%d/' % (url, last_build)
    f = urllib2.urlopen(url)
    page = f.read()

    image_url = url + 'Image'
    dt_url = url + "dtbs"
    modules_url = url + 'kernel-modules.tar.xz'

    repo = ''
    branch = ''
    version = ''
    rex = re.compile("^(?P<name>.*): (?P<var>.*)$")
    soup = BeautifulSoup(page, "html.parser")
    div = soup.find(id="content")
    for li in div.select('p > ul > li'):
        m = rex.search(li.text)
        if m:
            if 'KERNEL_REPO_URL' == m.group('name'):
                repo = m.group('var')
            if 'KERNEL_BRANCH' == m.group('name'):
                branch = m.group('var')
            if 'KERNEL_DESCRIBE' == m.group('name'):
                version = m.group('var')

    return (image_url, dt_url, modules_url, version)


# XXX: When the Jenkins trigger detects a new build (URL change) dosen't mean that the kernel
# defconfig build we are looking for is done so this check is needed to try in loop mode
# until defconfig is available and not register the build as done.
def validate_url(url):
    urllib2.urlopen(url)


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
    linaro_ci_base_url = os.environ.get('LINARO_CI_BASE_URL',
                                        'https://snapshots.linaro.org/member-builds/qcomlt/kernel/')

    machines = os.environ.get('MACHINES', 'apq8016-sbc apq8096-db820c').split()
    builds_url = os.environ.get('BUILDS_URL',
                                'https://snapshots.linaro.org/member-builds/qcomlt/linux-integration/%s/')

    machine_avail = os.environ.get('KERNEL_BUILD_MACHINE_AVAIL', False)

    image_url = None
    modules_url = None
    version = None

    (image_url, dt_url, modules_url, version) = get_linaro_ci_build(linaro_ci_base_url)

    print("KERNEL_DT_URL=%s" % dt_url)

    # Check that all DTBS exist, if machine_avail is set only remove from final
    # machine list.
    for m in machines[:]:
        dt_file_url = dt_url + "/qcom/%s.dtb" % m
        try:
            validate_url(dt_file_url)
        except urllib2.HTTPError as err:
            if err.code == 404:
                if machine_avail:
                    machines.remove(m)
                else:
                    raise Exception("DTB not found: %s" % dt_file_url)
            else:
                raise

        try:
            validate_if_already_built((builds_url % m), (image_url, dt_file_url, modules_url))
        except urllib2.HTTPError as e:
            # 404 can happen when no previous build exists
            if e.code != 404:
                raise

    if machine_avail and not machines:
        raise Exception("No machines available to build")

    print("KERNEL_IMAGE_URL=%s" % image_url)
    validate_url(image_url)
    print("KERNEL_MODULES_URL=%s" % modules_url)
    validate_url(modules_url)
    print("KERNEL_VERSION=%s" % version)
    print("MACHINES=%s" % ' '.join(machines))


if __name__ == '__main__':
    try:
        ret = main()
    except Exception:
        ret = 1
        import traceback
        traceback.print_exc()
    sys.exit(ret)
