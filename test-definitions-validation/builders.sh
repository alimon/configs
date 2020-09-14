#!/bin/bash

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python-pip
pip install ruamel.yaml jinja2
git clone git://git.linaro.org/ci/job/configs
python2 configs/openembedded-lkft/submit_for_testing.py \
        --device-type db845c \
        --build-number ${BUILD_NUMBER} \
        --lava-server https://validation.linaro.org \
        --qa-server https://qa-reports.linaro.org \
        --qa-server-team qa \
        --qa-server-project test-definitions-validation \
	--git-commit ${BUILD_NUMBER} \
        --testplan-path configs/test-definitions-validation/ \
        --test-plan test-db845c-1.yaml test-db845c-2.yaml test-db845c-3.yaml

python2 configs/openembedded-lkft/submit_for_testing.py \
        --device-type db410c \
        --build-number ${BUILD_NUMBER} \
        --lava-server https://lkft.validation.linaro.org \
        --qa-server https://qa-reports.linaro.org \
        --qa-server-team qa \
        --qa-server-project test-definitions-validation \
	--git-commit ${BUILD_NUMBER} \
        --testplan-path configs/test-definitions-validation/ \
        --test-plan test-db410c-1.yaml
