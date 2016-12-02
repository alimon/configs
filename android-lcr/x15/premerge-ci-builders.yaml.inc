        - linaro-publish-token
        - shell:
            !include-raw:
                - android-lcr/common/builders.sh
                - android-lcr/x15/builders.sh
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/x15/template-boottime.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
