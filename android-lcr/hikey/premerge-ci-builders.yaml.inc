        - linaro-publish-token
        - shell:
            !include-raw:
                - android-lcr/common/builders.sh
                - android-lcr/hikey/builders.sh
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-benchmarkpi.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-cf-bench.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-javawhetstone.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-linpack.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-quadrantpro.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-scimark.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-rl-sqlite.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-vellamo3.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-applications.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-caffeinemark.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-antutu6.0.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
