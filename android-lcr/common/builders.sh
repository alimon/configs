#!/bin/bash

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
  [[ -n ${SSH_AGENT_PID} ]] && kill -9 ${SSH_AGENT_PID} ||:
}

# Install needed packages
sudo add-apt-repository ppa:linaro-maintainers/tools
sudo sed -i -e 's/archive.ubuntu.com\|security.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list
sudo apt-get update
sudo apt-get install -y bison git gperf libxml2-utils python-mako zip time python-pycurl genisoimage patch mtools python-wand

# Install most recent linaro-image-tools (packaged) and dependencies
sudo apt-get install -y gdisk libyaml-0-2 python-apt python-chardet python-dbus python-dbus-dev \
  python-debian python-gi python-parted python-pkg-resources python-six python-yaml u-boot-tools \
  python-commandnotfound parted python-crypto
wget -q \
  http://repo.linaro.org/ubuntu/linaro-overlay/pool/main/a/android-tools/android-tools-fsutils_4.2.2+git20130218-3ubuntu41+linaro1_amd64.deb \
  http://repo.linaro.org/ubuntu/linaro-tools/pool/main/l/linaro-image-tools/linaro-image-tools_2016.05-1linarojessie1_amd64.deb \
  http://repo.linaro.org/ubuntu/linaro-tools/pool/main/l/linaro-image-tools/python-linaro-image-tools_2016.05-1linarojessie1_all.deb
sudo dpkg -i --force-all *.deb
rm -f *.deb

# Set local configuration
git config --global user.email "ci_notify@linaro.org"
git config --global user.name "Linaro CI"
java -version

BUILD_DIR=${BUILD_DIR:${JOB_NAME}}
if [ ! -d "/home/buildslave/srv/${BUILD_DIR}" ]; then
  sudo mkdir -p /home/buildslave/srv/${BUILD_DIR}
  sudo chmod 777 /home/buildslave/srv/${BUILD_DIR}
fi
cd /home/buildslave/srv/${JOB_NAME}

if [[ -n $PRIVATE_KEY ]]; then
# Handle private key
mkdir -p $HOME/.ssh

TMPKEYDIR=$(mktemp -d /tmp/linaroandroid.XXXXXX)
cat > ${TMPKEYDIR}/private-key-wrapper.py << EOF
#!/usr/bin/python

import os
import sys

def main():
    private_key = os.environ.get("PRIVATE_KEY", "Undefined")
    if private_key == "Undefined":
        sys.exit("PRIVATE_KEY is not defined.")

    buffer = private_key.replace(' ','\n')
    with open('linaro-private-key', 'w') as f:
        f.write('-----BEGIN RSA PRIVATE KEY-----\n')
        f.write(buffer)
        f.write('\n-----END RSA PRIVATE KEY-----\n')

if __name__ == "__main__":
        main()
EOF
python ${TMPKEYDIR}/private-key-wrapper.py
chmod 0600 linaro-private-key

eval `ssh-agent` >/dev/null 2>/dev/null
ssh-add linaro-private-key >/dev/null 2>/dev/null
rm -rf linaro-private-key ${TMPKEYDIR}

ssh-keyscan dev-private-git.linaro.org >> $HOME/.ssh/known_hosts
ssh-keyscan dev-private-review.linaro.org >> $HOME/.ssh/known_hosts
[[ -n "$GERRIT_HOST" ]] && ssh-keyscan $GERRIT_HOST >> $HOME/.ssh/known_hosts
cat << EOF >> $HOME/.ssh/config
Host dev-private-git.linaro.org
    User git
Host dev-private-review.linaro.org
    User git
EOF
chmod 0600 $HOME/.ssh/*
fi

# Download helper scripts (repo, linaro-cp)
mkdir -p ${HOME}/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
wget https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
chmod a+x ${HOME}/bin/*
export PATH=${HOME}/bin:${PATH}

# Install helper packages
rm -rf build-tools jenkins-tools build-configs build/out build/android-patchsets
git clone --depth 1 https://git.linaro.org/infrastructure/linaro-android-build-tools.git build-tools
git clone --depth 1 https://git.linaro.org/infrastructure/linaro-jenkins-tools.git jenkins-tools
git clone --depth 1 http://android.git.linaro.org/git/android-build-configs.git build-configs

set -xe
# Define job configuration's repo
export BUILD_CONFIG_FILENAME=${BUILD_CONFIG_FILENAME:-${JOB_NAME#android-*}}
cat << EOF > config.txt
BUILD_CONFIG_REPO=http://android.git.linaro.org/git/android-build-configs.git
BUILD_CONFIG_BRANCH=master
EOF
echo config.txt
export CONFIG=`base64 -w 0 config.txt`
export SKIP_LICENSE_CHECK=1
