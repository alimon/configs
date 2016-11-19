#!/bin/bash

set -e

# install pre-requisites
sudo apt-get -q=2 update
sudo apt-get -q=2 install -y --no-install-recommends \
  build-essential \
  gfortran \
  git \
  libblas-dev \
  liblapack-dev

# download jniloader
git clone --depth 1 https://github.com/fommil/jniloader.git

# download OpenJDK 8 and Maven 3.3.9 explicitely
wget --progress=dot -e dotbytes=2M ${JDK_URL} ${MAVEN_URL}
tar -Jxf jdk*.tar.xz
tar -zxf apache-maven-*.tar.gz

# replace cacerts with distro-supplied
cd jdk*/jre/lib/security/
rm -f cacerts
ln -s /etc/ssl/certs/java/cacerts

# set JAVA_HOME
cd ${WORKSPACE}/jdk*
export JAVA_HOME=${PWD}

# set M3_HOME
cd ${WORKSPACE}/apache-maven-*
export M3_HOME=${PWD}

# set PATH
export PATH=${JAVA_HOME}/bin:${M3_HOME}/bin:${PATH}
java -version
mvn -version

# build and hookup jniloader
cd ${WORKSPACE}/jniloader
mvn -B -Dgpg.skip clean install

cat << EOF > ${WORKSPACE}/netlib-java/bump-lombok-jniloader-version.patch
--- a/pom.xml
+++ b/pom.xml
@@ -181,7 +181,7 @@
             <dependency>
                 <groupId>org.projectlombok</groupId>
                 <artifactId>lombok</artifactId>
-                <version>1.12.2</version>
+                <version>1.12.6</version>
                 <scope>provided</scope>
             </dependency>
             <dependency>
@@ -209,7 +209,7 @@
             <dependency>
                 <groupId>com.github.fommil</groupId>
                 <artifactId>jniloader</artifactId>
-                <version>1.1</version>
+                <version>1.2-SNAPSHOT</version>
             </dependency>
             <dependency>
                 <groupId>net.sf.opencsv</groupId>
EOF

# build and hookup netlib-java
ARCH=$(uname -m)
(cd ${WORKSPACE}/netlib-java && patch -p1 < bump-lombok-jniloader-version.patch)
(cd ${WORKSPACE}/netlib-java/generator && mvn -B -Dgpg.skip clean install)
(cd ${WORKSPACE}/netlib-java/core && mvn -B -Dgpg.skip clean install)
(cd ${WORKSPACE}/netlib-java && mvn -B -Dgpg.skip -P${ARCH}-profile clean install)
(cd ${WORKSPACE}/netlib-java/native_ref/xbuilds && mvn -B -Dgpg.skip -P${ARCH}-profile clean install)
(cd ${WORKSPACE}/netlib-java/native_system/xbuilds && mvn -B -Dgpg.skip -P${ARCH}-profile clean install)

# prepare to archive the build artifacts
rm -rf ${WORKSPACE}/com && mkdir -p ${WORKSPACE}/com/github
cp -a ${HOME}/.m2/repository/com/github/fommil ${WORKSPACE}/com/github/
