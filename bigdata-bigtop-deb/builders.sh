#!/bin/bash

set -ex

# number of CPU_CORES to build with
export CPU_CORES=$(getconf _NPROCESSORS_ONLN)

# get source
rm -rf bigtop-trunk
git clone --depth 1 --branch working-tar-gz-packaging https://git.linaro.org/leg/bigdata/bigtop-trunk.git

# Before starting the container, give other users `w` access to `bigtop`
# home directory. It is required for gradle installation as 'jenkins' users.
# Otherwise, you will see this error when run 'gradlew tasks'.
#   FAILED: Could not create service of type CrossBuildFileHashCache
#    using BuildSessionScopeServices.createCrossBuildFileHashCache().
chmod a+w bigtop-trunk

# now build bigtop slaves
cd bigtop-trunk

# optionally, build docker images locally - only needed once
#./gradlew -POS=debian-9 -Pprefix=erp18.06 bigtop-puppet
#./gradlew -POS=debian-9 -Pprefix=erp18.06 bigtop-slaves

# build bigdata bigtop components. This will take a while.
# Artifacts will be stored under individual component folder inside output folder.
#
# Example command line:
#   docker run --rm -u jenkins --workdir /ws -v ${PWD}:/ws \
#          bigtop/slaves:1.4.0-debian-9-aarch64 bash -l -c '. /etc/profile.d/bigtop.sh; ./gradlew deb repo'
#
# Note:
#   - User 'jenkins' is employed. It exists by default in the root docker image of bigtop/slaves.
#   - It's not allowed using 'root' to build bigtop. Some component refuses to be built in root.
#   - Image "bigtop/slaves:*-aarch64" will be retrieved from docker hub on live.
#   - bigtop.sh sets environment variables such as: JAVA_HOME, MAVEN_HOME, ANT_HOME, GRADLE_HOME, etc.

docker run --rm -u jenkins --workdir /ws -v ${PWD}:/ws \
  bigtop/slaves:1.4.0-debian-9-aarch64 bash -l -c '. /etc/profile.d/bigtop.sh; ./gradlew deb repo; chmod -R a+w output build .gradle dl;'

# cleanup
#docker prune -fa
