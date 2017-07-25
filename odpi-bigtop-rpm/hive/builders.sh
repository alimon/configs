# okay everything is in place, this build will take a while
./gradlew clean hive-rpm \
  -Pdist,native-win \
  -DskipTests \
  -Dtar \
  -Dmaven.javadoc.skip=true \
  -PHadoop-2.7 \
  -Phadoop.version=2.7.3 \
  --debug
