#!/bin/bash
# build dependencies on Debian:
# git build-essential virtualenv python-dev libffi-dev libssl-dev

kolla_branch=${BRANCH}
kolla_ldc=${DEVCLOUD}
kolla_ldc_extras=${DEVCLOUD_EXTRA_PATCHES}
kolla_options=

if [ -z "${kolla_branch}" -o "${kolla_branch}" == "master" ]; then
    kolla_branch=master
    kolla_tag=rocky-${BUILD_NUMBER}
else
    if [ -z "${kolla_ldc}" ]; then
        kolla_tag=queens-${BUILD_NUMBER}
    else
        patches_count=0
        if [ ! -z ${kolla_ldc_extras} ]; then
            patches_count=$(echo ${kolla_ldc_extras} | tr ',' ' ' | wc -w)
        fi

        if [ "${patches_count}" -eq "0" ]; then
            kolla_tag=ldc-queens-${BUILD_NUMBER}
        else
            kolla_tag=ldc-queens-${BUILD_NUMBER}-p${patches_count}
        fi

        kolla_options="--template-override ../Linaro-overlay/linaro-override.j2"
    fi
fi

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    rm -rf ${HOME}/.docker
}

mkdir -p ${HOME}/.docker
sed -e "s|\${DOCKER_AUTH}|${DOCKER_AUTH}|" < ${WORKSPACE}/config.json > ${HOME}/.docker/config.json
chmod 0600 ${HOME}/.docker/config.json

rm -rf ${WORKSPACE}/*

wget -q http://git.linaro.org/ci/job/configs.git/plain/leg-kolla/linaro.conf -O ${WORKSPACE}/linaro.conf

git clone --depth 1 --branch ${kolla_branch} https://git.openstack.org/openstack/kolla

if [ -n ${kolla_ldc} ]; then
    git clone --depth 1 https://git.linaro.org/leg/sdi/kolla/ldc-overlay.git Linaro-overlay
fi

# Rocky always tries to build it and it fails for us
# to be debugged later
if [ ${kolla_branch} == "master" ]; then
    rm -rf kolla/docker/neutron/neutron-server-opendaylight
fi

# Apply extra patches to the kolla source code that haven't
# been merged into the stable/queens branch.
if [[ ! -z ${kolla_ldc} && ! -z ${kolla_ldc_extras} ]]; then
    echo ${kolla_ldc_extras} | sed -n 1'p' | tr ',' '\n' | while read patch; do
        curl https://git.openstack.org/cgit/openstack/kolla/patch/?id=${patch} | git apply -v --directory=kolla/
    done
fi

virtualenv --python=/usr/bin/python2 venv-for-kolla
. venv-for-kolla/bin/activate

cd kolla

pip install -r requirements.txt

mkdir -p logs/debian-source

kolla_namespace=linaro
./tools/build.py --base debian \
                 --format none \
                 ${kolla_options} \
                 --logs-dir logs/debian-source \
                 --config-file ${WORKSPACE}/linaro.conf \
                 --profile linaro \
                 --pull \
                 --retries ${RETRIES_OPT} \
                 --threads ${THREADS_OPT} \
                 --tag ${kolla_tag} \
                 --type source \
                 --namespace ${kolla_namespace}

docker images | grep ${kolla_tag} | cut -d" " -f1 >list-of-images

cat list-of-images

wc -l list-of-images

echo "kolla_tag=${kolla_tag}" >${WORKSPACE}/push.parameters
