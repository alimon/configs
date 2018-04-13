        - shell:
            echo "CI_MAIL_RECIPIENTS=op-tee@linaro.org" > env_var_parameters
        - inject:
            properties-file: env_var_parameters
        - shell:
            !include-raw:
                - android-lcr/common/builders.sh
                - android-lcr/hikey/builders-v2.sh
