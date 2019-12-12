#!/usr/bin/python3

import os
import sys
import requests
import json

from urllib.parse import urljoin

BACKEND_URL = "https://api.kernelci.org"

def main(token, job, arch, defconfig, output='output.log'):
    headers = {
        "Authorization": token
    }

    params = {
        "job": job,
        "arch": arch,
        "defconfig_full": defconfig,
        "date_range": 2,
        "status": "PASS",
    }

    url = urljoin(BACKEND_URL, "/builds")
    req = requests.get(url, params=params, headers=headers)
    if req.status_code != 200:
        raise Exception("Unable to download %s" % url)

    resp = req.json()

    os.makedirs(".builds", exist_ok=True)
    for build in resp['result']:
        status = '.builds/' + '_'.join([build[key] for key in ['job', 'git_describe', 'arch', 'defconfig_full']])
        if os.access(status, os.R_OK):
            continue

        workdir = '/'.join([build[key] for key in ['job', 'git_describe', 'arch', 'defconfig_full']])
        with open(status, 'w') as f:
            os.utime(status)

        print("Found something!")
        res_url = "https://storage.kernelci.org/" + build['file_server_resource'] + "/"
        print(res_url)
        with open(output, 'w') as f:
            f.write("KERNEL_IMAGE_URL=" + res_url + build['kernel_image'] + '\n')
            f.write("KERNEL_MODULES_URL=" + res_url + build['modules'] + '\n')
            f.write("KERNEL_VERSION=" + build['git_describe'] + '\n')
            f.write("KERNEL_DT_URL=" + res_url + build['dtb_dir'] + '\n')

        # let's quit, process one new job at max
        sys.exit(0)

    # nothing to do
    sys.exit(1)

if __name__ == "__main__":
    main(*sys.argv[1:])
