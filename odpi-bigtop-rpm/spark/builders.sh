# okay everything is in place, this build will take a while
./gradlew clean spark-rpm \
  -Pdist,native-win \
  -DskipTests \
  -Dtar \
  -Dmaven.javadoc.skip=true \
  -PHadoop-2.7 \
  -Pyarn \
  -Phadoop.version=2.7.3 \
  -Dscala-2.11 \
  --debug
