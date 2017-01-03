        - linaro-publish-token
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
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            sed -i "s#CUSTOM_JSON_URL=.*#CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/lcr-member-juno-m/template-boottime.json#g" ${WORKSPACE}/post_build_lava_parameters
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters
              block: true
        - shell: |
            echo "Build finished"
