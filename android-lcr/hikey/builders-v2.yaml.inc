        - shell:
            !include-raw:
                - android-lcr/common/builders.sh
                - android-lcr/hikey/builders-v2.sh
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
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-boottime.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-xtest-lmg.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-monkey.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-focused1-v8a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-focused1-v7a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-focused2-v8a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-focused2-v7a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-benchmarkpi.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cf-bench.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-gearses2eclair.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-geekbench3.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-javawhetstone.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-jbench.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-linpack.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-quadrantpro.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-scimark.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-rl-sqlite.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-vellamo3.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-caffeinemark.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-antutu6.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-andebenchpro2015.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            if [ -n "$GERRIT_PROJECT" ]; then
                echo "SKIP_LAVA=1" >> ${WORKSPACE}/post_build_lava_parameters
            fi
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-part1-v8a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-part1-v7a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-part2-v8a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-part2-v7a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-part3-v8a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-part3-v7a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-part4-v8a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-part4-v7a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-part5-v8a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-part5-v7a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-opengl-v8a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-opengl-v7a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-media-v8a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-media-v7a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-media2-v8a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-cts-media2-v7a.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-weekly.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-vts-part1.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-vts-part2.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-vts-part3.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-vts-part4.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-vts-part5.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-vts-part6.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template-glbenchmark25.yaml#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
