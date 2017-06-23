        - shell:
            !include-raw:
                - android-lcr/common/builders.sh
                - android-lcr/hikey/builders.sh
        - inject:
            properties-file: publish_parameters
        - linaro-publish-token
        - shell:
            !include-raw:
                - android/linaro-publisher.sh
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-boottime.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-xtest-lmg.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-cts-focused1.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-cts-focused2.json#g" ${WORKSPACE}/post_build_lava_parameters
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
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-gearses2eclair.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-geekbench3.json#g" ${WORKSPACE}/post_build_lava_parameters
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
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-jbench.json#g" ${WORKSPACE}/post_build_lava_parameters
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
        - shell: |
            if [ -n "$GERRIT_PROJECT" ]; then
                echo "SKIP_LAVA=1" >> ${WORKSPACE}/post_build_lava_parameters
            fi
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-cts-part1.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-cts-part2-64.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-cts-part2-32.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-cts-part3.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-cts-part4.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-cts-opengl.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-cts-media-32.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-cts-media-64.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-andebenchpro2015.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-glbenchmark-2.5.1.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template-weekly.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
