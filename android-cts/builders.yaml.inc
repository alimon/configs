        - shell:
            !include-raw:
                - android-lcr/common/builders.sh
                - android-cts/builders.sh
        - inject:
            properties-file: publish_parameters
        - linaro-publish-token
        - shell:
            !include-raw:
                - android/linaro-publisher.sh
