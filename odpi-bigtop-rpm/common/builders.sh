#!/bin/bash

set -ex

# number of CPU_CORES to build with
export CPU_CORES=$(getconf _NPROCESSORS_ONLN)

# install pre-requisites
sudo yum install -y \
  apache-ivy \
  ant \
  asciidoc \
  chrpath \
  cmake \
  cppunit-devel \
  cyrus-sasl-devel \
  fuse \
  fuse-devel \
  gcc-c++ \
  jansson-devel \
  krb5-devel \
  lcms2-devel \
  libtool \
  libxml2-devel \
  libxslt-devel \
  libyaml-devel \
  libzip-devel \
  lzo-devel \
  make \
  mariadb-devel \
  java-1.8.0-openjdk \
  openldap-devel \
  openssl-devel \
  pkgconfig \
  python-devel \
  python-setuptools \
  rpm-build \
  rsync \
  sharutils \
  snappy-devel \
  sqlite-devel \
  subversion \
  unzip \
  wget \
  xmlto

# download some dependencies explicitely
wget --progress=dot -e dotbytes=2M ${MAVEN_URL} ${SCALA_URL} ${NODE_URL} ${PROTOBUF_URL}
tar -zxf apache-maven-*.tar.gz
tar -zxf scala-*.tgz
tar -zxf node-*.tar.gz
tar -zxf protobuf-*.tar.gz

# set M3_HOME
cd ${WORKSPACE}/apache-maven-*
export M3_HOME=${PWD}

# FIXME switch to nexus.linaro.org
# hack to use archiva
#wget -q http://people.linaro.org/~fathi.boudra/settings.xml -O conf/settings.xml
#mkdir ~/.m2
#cp -a conf/settings.xml ~/.m2/settings.xml

# set SCALA_HOME
cd ${WORKSPACE}/scala-*
export SCALA_HOME=${PWD}

# set PATH
export PATH=${M3_HOME}/bin:${PATH}
java -version
mvn -version

# build and hookup nodejs
cd ${WORKSPACE}/node-*
./configure --prefix=${WORKSPACE}/node
make -j${CPU_CORES} install
export PATH=${WORKSPACE}/node/bin/:${PATH}

# build and hookup protobuf compiler
cd ${WORKSPACE}/protobuf-*
./configure --prefix=${WORKSPACE}/protobuf
make -j${CPU_CORES} install
export PATH=${WORKSPACE}/protobuf/bin:${PATH}
export PKG_CONFIG_PATH=${WORKSPACE}/protobuf/lib/pkgconfig

# clone the ODPi BigTop definitions
git clone --depth 1 https://git.linaro.org/leg/bigdata/bigtop-trunk.git -b erp17.08 ${WORKSPACE}/odpi-bigtop
cd ${WORKSPACE}/odpi-bigtop

# FIXME Upstream protobuf version 2.5.0 does not support AArch64. Bump up to 2.6.1.
git config --global user.name "Linaro CI"
git config --global user.email "ci_notify@linaro.org"
git remote add scapper https://git.linaro.org/people/steve.capper/odpi-bigtop.git
git fetch scapper
git cherry-pick 3033ede8c0a0ede0323c4e8c946d1293ed64729c
git cherry-pick a4ef371718fc32d25cc01137e559da4079368773
