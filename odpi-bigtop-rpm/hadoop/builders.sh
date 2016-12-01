# okay everything is in place, this build will take a while
./gradlew clean hadoop-rpm \
  -Pdist,native-win \
  -DskipTests \
  -Dtar \
  -Dmaven.javadoc.skip=true \
  --debug
