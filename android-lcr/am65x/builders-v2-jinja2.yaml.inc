        - shell:
            !include-raw:
                - android-lcr/common/builders.sh
                - android-lcr/am65x/builders-v2.sh
        - inject:
            properties-file: publish_parameters
        - linaro-publish-token
        - shell:
            !include-raw:
                - android/linaro-publisher.sh
        - inject:
            properties-file: post_build_lava_parameters
        - shell:
            !include-raw:
                - android-lcr/common/submit_for_testing.sh
