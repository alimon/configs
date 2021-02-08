#!/bin/bash
# build dependencies on Debian:
# git build-essential virtualenv python-dev libffi-dev libssl-dev

kolla_branch=${BRANCH}
kolla_ldc=${DEVCLOUD}
kolla_ldc_extras=${DEVCLOUD_EXTRA_PATCHES}
kolla_options=
kolla_python=/usr/bin/python3
ceph_version=${CEPH_VERSION}

if [ -z "${kolla_branch}" -o "${kolla_branch}" == "master" ]; then
    branch="victoria"
elif [[ ${kolla_branch} = "stable"* ]]; then
    branch=$(echo ${kolla_branch} | sed -e 's+stable/++g')
else
    echo "Choose something"
    exit 1
fi

if [ ! -z "${kolla_ldc}" ]; then

    patches_count=0
    if [ ! -z ${kolla_ldc_extras} ]; then
        patches_count=$(echo ${kolla_ldc_extras} | tr ',' ' ' | wc -w)
    fi

    if [ "${patches_count}" -eq "0" ]; then
        kolla_tag=ldc-${branch}-${BUILD_NUMBER}
    else
        kolla_tag=ldc-${branch}-${BUILD_NUMBER}-p${patches_count}
    fi

else
    kolla_tag=${branch}-${BUILD_NUMBER}
fi

set -ex

trap failure_exit INT TERM ERR
trap cleanup_exit EXIT

cleanup_exit()
{
    rm -rf ${HOME}/.docker
}

failure_exit()
{
    # we failed - remove images
    docker images --filter reference="linaro/debian-source*:${kolla_tag}" --quiet|xargs docker image rm
    cleanup_exit
}

rm -rf ${WORKSPACE}/*

wget -q http://git.linaro.org/ci/job/configs.git/plain/leg-kolla/linaro.conf -O ${WORKSPACE}/linaro.conf

git clone --depth 1 --branch ${kolla_branch} https://opendev.org/openstack/kolla.git

if [ -n ${kolla_ldc} ]; then
    git clone --depth 1 https://git.linaro.org/leg/sdi/kolla/ldc-overlay.git Linaro-overlay

    override_file="${WORKSPACE}/Linaro-overlay/linaro-override.j2"

    if [ -e "${WORKSPACE}/Linaro-overlay/linaro-override-${branch}.j2" ]; then
	override_file="${WORKSPACE}/Linaro-overlay/linaro-override-${branch}.j2"
    fi

    kolla_options="--template-override ${override_file} --profile devcloud "

    # applied unmerged patches for ussuri
    if [[ $branch = "ussuri" ]]; then
        cat <<EOF >> ${WORKSPACE}/linaro.conf

[cinder-base]
type = git
location = https://github.com/xin3liang/cinder.git
reference = ${kolla_branch}-ldc

[ironic-base]
type = git
location = https://github.com/xin3liang/ironic.git
reference = ${kolla_branch}-ldc

[nova-base]
type = git
location = https://github.com/xin3liang/nova.git
reference = ${kolla_branch}-ldc
EOF
    fi
fi

# Apply extra patches to the kolla source code that haven't
# been merged into the branch.
if [[ ! -z ${kolla_ldc} && ! -z ${kolla_ldc_extras} ]]; then
    echo ${kolla_ldc_extras} | sed -n 1'p' | tr ',' '\n' | while read patch; do
        curl "https://review.opendev.org/changes/openstack%2Fkolla~${patch}/revisions/current/patch" | base64 -d | git apply -v --directory=kolla/
    done
fi

virtualenv --python=${kolla_python} venv-for-kolla
. venv-for-kolla/bin/activate

cd kolla

pip install -r requirements.txt

mkdir -p ${WORKSPACE}/kolla/logs/debian-source

kolla_namespace=linaro
./tools/build.py --base debian \
                 --format none \
                 ${kolla_options} \
                 --logs-dir logs/debian-source \
                 --config-file ${WORKSPACE}/linaro.conf \
                 --pull \
                 --retries ${RETRIES_OPT} \
                 --threads ${THREADS_OPT} \
                 --tag ${kolla_tag} \
                 --type source \
                 --namespace ${kolla_namespace}

docker images | grep ${kolla_tag} | cut -d" " -f1 | sort >list-of-images

cat list-of-images

wc -l list-of-images

echo "kolla_tag=${kolla_tag}" >${WORKSPACE}/push.parameters
