        - shell: |
            CI_MAIL_RECIPIENTS="victor.chong@linaro.org"
            echo "CI_MAIL_RECIPIENTS=${CI_MAIL_RECIPIENTS}" > env_var_parameters
        - inject:
            properties-file: env_var_parameters
        - shell:
            !include-raw:
                - android-lcr/common/builders.sh
                - android-lcr/hikey/builders-v2.sh
