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
    branch="ussuri"
elif [[ ${kolla_branch} = "stable"* ]]; then
    branch=$(echo ${kolla_branch} | sed -e 's+stable/++g')

    if [[ ${kolla_branch} = "rocky" ]]; then
        kolla_python=/usr/bin/python2
    fi
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

    kolla_options="--template-override ../Linaro-overlay/linaro-override-${branch}.j2  --profile devcloud_${branch} "

else
    kolla_tag=${branch}-${BUILD_NUMBER}
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

git clone --depth 1 --branch ${kolla_branch} https://opendev.org/openstack/kolla.git

if [ -n ${kolla_ldc} ]; then
    git clone --depth 1 https://git.linaro.org/leg/sdi/kolla/ldc-overlay.git Linaro-overlay

    if [ 'rocky' != '${branch}' ]; then

        # We may want to use Ceph nautilus from backports
        # It is not mergeable upstream
        # We also want kibana and libvirt with ThunderX fixes
        cat <<EOF >> kolla/docker/base/sources.list.debian

# Enable backports
deb http://deb.debian.org/debian buster-backports main

# Linaro - fixed libvirt and kibana
deb http://obs.linaro.org/home:/marcin.juszkiewicz/debian-buster ./
EOF

        cat <<EOF >> kolla/docker/base/apt_preferences.debian

# We do not want packages from this repo
Package: *
Pin: release o=obs://private/home:marcin.juszkiewicz/debian-buster
Pin-Priority: 100

# Unless it is libvirt or kibana
Package: *libvirt* kibana
Pin: release o=obs://private/home:marcin.juszkiewicz/debian-buster
Pin-Priority: 600
EOF

	sed -i -e s+"'http://buster-train.debian.net/debian/dists/pubkey.gpg',"+"'http://buster-train.debian.net/debian/dists/pubkey.gpg','http://obs.linaro.org/home:/marcin.juszkiewicz/debian-buster/Release.key',"+g kolla/docker/base/Dockerfile.j2

	if [ 'luminous_erp' = $ceph_version ]; then
		kolla_tag="${kolla_tag}-lumerp"
		cat <<EOF >> kolla/docker/base/apt_preferences.debian

# We want Ceph/nautilus
Package: ceph* libceph* librados* librbd* librgw* python*-ceph* python*-rados python*-rbd python*-rgw radosgw
Pin: version 12.2.4*
Pin-Priority: 1000
EOF
	fi

	if [ 'nautilus' = $ceph_version ]; then
		kolla_tag="${kolla_tag}-nautilus"
		cat <<EOF >> kolla/docker/base/apt_preferences.debian

# We want Ceph/nautilus
Package: ceph* libceph* librados* librbd* librgw* python3-ceph* python3-rados python3-rbd python3-rgw radosgw
Pin: version 14.*
Pin-Priority: 1000

# ceph-osd requires smartmontools from backports
Package: smartmontools
Pin: version 7.*
Pin-Priority: 1000
EOF

	fi

	# we want to build Kibana images
	sed -i -e /"kibana"/d kolla/kolla/image/build.py
    fi
fi

# Apply extra patches to the kolla source code that haven't
# been merged into the stable/queens branch.
if [[ ! -z ${kolla_ldc} && ! -z ${kolla_ldc_extras} ]]; then
    echo ${kolla_ldc_extras} | sed -n 1'p' | tr ',' '\n' | while read patch; do
        curl "https://review.opendev.org/gitweb?p=openstack/kolla.git;a=patch;h=${patch}" | git apply -v --directory=kolla/
    done
fi

virtualenv --python=${kolla_python} venv-for-kolla
. venv-for-kolla/bin/activate

cd kolla

pip install -r requirements.txt

mkdir -p ${WORKSPACE}/kolla/logs/debian-source

# if job fails then remove-images job will be triggered to do cleanup
echo "kolla_tag=${kolla_tag}" >${WORKSPACE}/remove.parameters

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

# job succedded so do not remove images yet (push will do it)
rm ${WORKSPACE}/remove.parameters
