        - shell:
            !include-raw:
                - android-lcr/common/builders.sh
                - android-tv/hikey/builders.sh
        - inject:
            properties-file: publish_parameters
        - linaro-publish-token
        - shell:
            !include-raw:
                - android/linaro-publisher.sh
        - trigger-builds:
            - project: 'post-build-lava'
              prooperty-file: post_build_lava_parameters
              block: true
