#!/bin/bash

set -e

echo ""
echo "########################################################################"
echo "    Gerrit Environment"
env |grep '^GERRIT'
echo "########################################################################"


cd terraform/
export GIT_PREVIOUS_COMMIT=$(git rev-parse HEAD~1)
export GIT_COMMIT=${GERRIT_PATCHSET_REVISION}
files=$(git diff --name-only ${GIT_PREVIOUS_COMMIT} ${GIT_COMMIT})
echo Changes in: ${files}
changed_dirs=$(dirname ${files})
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
for dir in ${changed_dirs}; do
    cd $dir
    terraform init
    terraform plan --var-file *.tfvars -out demo.plan
    cd ..
done

