#!/bin/bash

update_terraform()
{
    export TFVERS=0.11.14
    mkdir -p ̃~/.local/bin
    if [ ! -x ~/.local/bin/terraform_${TFVERS} ]
    then
        (
        cd /tmp
        wget -q https://releases.hashicorp.com/terraform/${TFVERS}/terraform_${TFVERS}_linux_amd64.zip
        unzip terraform_${TFVERS}_linux_amd64.zip
        cp terraform ~/.local/bin/terraform_${TFVERS}
        chmod a+x ~/.local/bin/terraform_${TFVERS}
        ln -sf terraform_${TFVERS}  ~/.local/bin/terraform
        )
    fi
}

set -e

cd terraform/
topdir=$(pwd)
export GIT_PREVIOUS_COMMIT=$(git rev-parse HEAD~1)
export GIT_COMMIT=${GERRIT_PATCHSET_REVISION}
files=$(git diff --name-only ${GIT_PREVIOUS_COMMIT} ${GIT_COMMIT})
echo Changes in: ${files}
changed_dirs=$(dirname ${files}|uniq)
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export PATH=${PATH}:${HOME}/.local/bin

update_terraform

for dir in ${changed_dirs}; do
    [ "${dir}" = "." ] && continue
    if [[ ${dir} == modules* ]]; then
        echo "skipping module dir ${dir}"
        continue
    fi
    cd $dir
    echo "================= $dir =========================="
    if ! compgen -G "*.tf" > /dev/null; then
        echo "no terraform files in this directory, skipping"
        continue
    fi
    if compgen -G "*.tfvars" > /dev/null; then
        echo "adding vars files to commandline"
        vars="--var-file *.tfvars"
    else
        vars=""
    fi
    terraform init > /dev/null
    terraform plan $vars -out demo.plan
    terraform 0.12checklist
    cd $topdir
done

