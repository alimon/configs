        - shell: |
            CI_MAIL_RECIPIENTS="victor.chong@linaro.org"
            echo "CI_MAIL_RECIPIENTS=${CI_MAIL_RECIPIENTS}" > env_var_parameters
        - inject:
            properties-file: env_var_parameters
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
        - shell: |
            echo "Build finished"
