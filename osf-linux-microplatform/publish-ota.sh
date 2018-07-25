#/bin/bash
sudo apt-get update
sudo apt-get install -y zip wget xz-utils
cd ${CREDENTIALS}/
zip credentials.zip *
cd -
cp ${CREDENTIALS}/credentials.zip .
wget https://raw.githubusercontent.com/OpenSourceFoundries/extra-containers/master/aktualizr/ota-publish.sh
chmod a+x ota-publish.sh

wget -q ${BUILD_URL}/ostree_repo.tar.xz
tar -xf ostree_repo.tar.xz

./ota-publish.sh -m hikey -c credentials.zip -r ostree_repo
