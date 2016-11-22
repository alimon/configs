#!/bin/bash

commit=$(git log -1 --format="%H")
tags=$(git tag --points-at HEAD)
tag=$(echo ${tags} | rev | cut -d' ' -f1 | rev)
if [ ! ${tag} ]; then
  git tag -a -m "${RELEASE_TAG} Release" ${RELEASE_TAG}
  remote=$(git remote -v | grep -m1 fetch | cut -d$'\t' -f2 | cut -d' ' -f1 | sed -e "s/http:\/\/android-git.linaro.org/ssh:\/\/${GERRIT_USER}@android-review.linaro.org:29418/g" -e "s/\/git\//\//g")
  git remote add upstream ${remote}
  git push upstream ${RELEASE_TAG} -f
  sed -i "s/${commit}/refs\/tags\/${RELEASE_TAG}/g" ${WORKSPACE}/out/R-LCR.xml
else
  sed -i "s/${commit}/refs\/tags\/${tag}/g" ${WORKSPACE}/out/R-LCR.xml
fi
