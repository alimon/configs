#!/bin/bash

set -ex

# number of CPU_CORES to build with
export CPU_CORES=$(getconf _NPROCESSORS_ONLN)

# get source
rm -rf bigtop-trunk
git clone --depth 1 --branch erp18.06 https://git.linaro.org/leg/bigdata/bigtop-trunk.git

# now build bigtop slaves
cd bigtop-trunk
# build docker images locally
./gradlew -POS=debian-9 -Pprefix=erp18.06 bigtop-puppet
./gradlew -POS=debian-9 -Pprefix=erp18.06 bigtop-slaves

# build bigdata bigtop components using locally built docker image. This will take a while.
# Artifacts will be stored under individual component folder inside output folder.
# components to be built: ambari bigtop-groovy bigtop-jsvc bigtop-tomcat bigtop-utils hadoop hbase hive spark zookeeper
# docker run -v ${PWD}:/ws bigtop/slaves:erp18.06-debian-9-aarch64 bash -l -c 'cd /ws ; ./gradlew <comp>-deb'
docker run -v ${PWD}:/ws bigtop/slaves:erp18.06-debian-9-aarch64 bash -l -c 'cd /ws ; ./gradlew hadoop-deb zookeeper-deb spark-deb hive-deb hbase-deb ambari-deb'

# cleanup
#docker prune -fa
