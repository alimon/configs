        - shell: |
            CI_MAIL_RECIPIENTS="${GERRIT_CHANGE_OWNER_EMAIL},${GERRIT_EVENT_ACCOUNT_EMAIL}"
            CI_MAIL_RECIPIENTS="${CI_MAIL_RECIPIENTS},vishal.bhoj@linaro.org"
            CI_MAIL_RECIPIENTS="${CI_MAIL_RECIPIENTS},daniel.diaz@linaro.org"
            echo "CI_MAIL_RECIPIENTS=${CI_MAIL_RECIPIENTS}" > env_var_parameters
        - inject:
            properties-file: env_var_parameters
        - shell:
            !include-raw:
                - android-lcr/common/builders.sh
                - android-lcr/juno/builders.sh
        - inject:
            properties-file: publish_parameters
        - linaro-publish-token
        - shell:
            !include-raw:
                - android/linaro-publisher.sh
        - shell: |
            echo "Build finished"
