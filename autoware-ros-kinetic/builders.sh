#!/bin/bash

set -e

cd ${WORKSPACE}/ros

# We first build the entire workspace normally
colcon build --cmake-args \
  -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -fprofile-arcs -ftest-coverage" \
  -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS} -fprofile-arcs -ftest-coverage" \
  -DCMAKE_BUILD_TYPE=Debug

# And then build the tests target. catkin (ROS1) packages add their tests to the tests target
# which is not the standard target for CMake projects. We need to trigger the tests target so that
# tests are built and any fixtures are set up.
colcon build --cmake-target tests --cmake-args \
  -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -fprofile-arcs -ftest-coverage" \
  -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS} -fprofile-arcs -ftest-coverage" \
  -DCMAKE_BUILD_TYPE=Debug

lcov --initial --directory build --capture --output-file lcov.base
colcon test
colcon test-result
lcov --directory build --capture --output-file lcov.test
lcov -a lcov.base -a lcov.test -o lcov.total
lcov -r lcov.total '*/tests/*' '*/test/*' '*/build/*' '*/devel/*' '*/install/*' '*/log/*' '/usr/*' '/opt/*' '/tmp/*' '*/CMakeCCompilerId.c' '*/CMakeCXXCompilerId.cpp' -o lcov.total.filtered
