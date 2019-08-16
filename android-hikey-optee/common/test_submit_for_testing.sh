#!/bin/bash -ex

PARENT_DIR=$(cd $(dirname $0); pwd)

virtualenv .venv
source .venv/bin/activate
pip install Jinja2 requests urllib3 ruamel.yaml

export ART_URL=https://android-qa-reports.linaro.org/api/
export BUILD_DIR=r-lcr-oreo
export BUILD_DISPLAY_NAME=#38
export BUILD_ID=38
export BUILD_NUMBER=38
export GERRIT_BRANCH=master
export GERRIT_CHANGE_COMMIT_MESSAGE=dXBkYXRlIHRvIHRhZyBhbmRyb2lkLTguMS4wX3IyCgpUaGUgY2hhbmdlIGxvZyBjb3VsZCBiZSBjaGVja2VkIGhlcmU6IGh0dHA6Ly9wZW9wbGUubGluYXJvLm9yZy9+eW9uZ3Fpbi5saXUvQ2hhbmdlTG9ncy9DaGFuZ2VMb2ctYW5kcm9pZC04LjEuMF9yMS1hbmRyb2lkLTguMS4wX3IyLTIwMTctMTItMTgtMDMtMzAtMzEudHh0CgpDaGFuZ2UtSWQ6IEkxMTAzZTdlMzJkMzBiOWNhZjY3NjM4NTk4NzVjYjYxNGE5OTRmODY4ClNpZ25lZC1vZmYtYnk6IFlvbmdxaW4gTGl1IDx5b25ncWluLmxpdUBsaW5hcm8ub3JnPgo=
export GERRIT_CHANGE_ID=I1103e7e32d30b9caf6763859875cb614a994f868
export GERRIT_CHANGE_NUMBER=18010
export GERRIT_CHANGE_SUBJECT=android-9.0.0_r34
export GERRIT_CHANGE_URL=http://android-review.linaro.org/18010
export GERRIT_EVENT_HASH=1581147094
export GERRIT_EVENT_TYPE=change-merged
export GERRIT_HOST=android-review.linaro.org
export GERRIT_NAME=android-review.linaro.org
export GERRIT_NEWREV=ded592ed8683143217b56c3915d00eef1d5abb12
export GERRIT_PATCHSET_NUMBER=1
export GERRIT_PATCHSET_REVISION=ded592ed8683143217b56c3915d00eef1d5abb12
export GERRIT_PORT=29418
#export GERRIT_PROJECT=android-build-configs
export GERRIT_REFSPEC=refs/changes/10/18010/1
export GERRIT_SCHEME=ssh
export GERRIT_TOPIC=
export GERRIT_VERSION=2.14.4
export JOB_BASE_NAME=android-hikey-optee-p
export JOB_NAME=android-hikey-optee-p
export JOB_URL=https://ci.linaro.org/job/android-hikey-optee-p/
export PUB_DEST=/android/android-hikey-optee-p/38
export PUB_SRC=/home/buildslave/srv/r-lcr-oreo/build/out
export RUN_CHANGES_DISPLAY_URL=https://ci.linaro.org/job/android-hikey-optee-p/38/display/redirect?page=changes
export RUN_DISPLAY_URL=https://ci.linaro.org/job/android-hikey-optee-p/38/display/redirect
export BUILD_URL=https://ci.linaro.org/job/android-hikey-optee-p/38/
export CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/x15-v2/template.yaml
export DOWNLOAD_URL=http://snapshots.linaro.org//android/android-hikey-optee-p/38
export EXECUTOR_NUMBER=18
export FRONTEND_JOB_NAME=android-hikey-optee-p
export IMAGE_EXTENSION=img
export JOB_NAME=android-hikey-optee-p
export JOB_URL=https://ci.linaro.org/job/post-build-lava/
export LAVA_SERVER=validation.linaro.org/RPC2/
export MAKE_TARGETS=droidcore
export SKIP_REPORT=false
export TARGET_PRODUCT=hikey
#export ANDROID_VERSION_SUFFIX=master
#export CTS_PKG_URL=http://testdata.linaro.org/cts/android-cts-master-linux_x86-arm-linaro.zip
#export VTS_PKG_URL=http://testdata.linaro.org/vts/master/android-vts.zip

export QA_SERVER=https://qa-reports.linaro.org/
export QA_SERVER_PROJECT=lcr
export QA_BUILD_VERSION=${BUILD_NUMBER}
export QA_REPORTS_TOKEN=secret
export ARTIFACTORIAL_TOKEN=artifactorial_token
export AP_SSID=ap_ssid
export AP_KEY=ap_key


export DRY_RUN=true

for device in $(ls ${PARENT_DIR}/../../android-lcr/lava-job-definitions/devices); do
    case "$device" in
      hi6220-hikey)
        ;&
      hi6220-hikey-bl)
        export DEVICE_TYPE=$device
        echo ${DEVICE_TYPE}
        bash ${PARENT_DIR}/submit_for_testing.sh
        ;;
      *)
        ;;
    esac
done

# cleanup virtualenv
deactivate
rm -rf .venv
