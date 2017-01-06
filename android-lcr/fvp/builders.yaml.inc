        - shell:
            !include-raw:
                - android-lcr/common/builders.sh
                - android-lcr/fvp/builders.sh
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
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/lcr-member-fvp-m/template-cts-bionic.json#g" ${WORKSPACE}/post_build_lava_parameters
