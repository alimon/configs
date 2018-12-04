        - email-ext:
            recipients: '${CI_MAIL_RECIPIENTS}'
            content-type: text
            body: |
                Build Triggered by:
                     1. https://git.linaro.org/ci/job/configs.git/tree/trigger-android-{daily,weekly}-builds.yaml
                     or
                     2. ${GERRIT_CHANGE_SUBJECT}: ${GERRIT_CHANGE_URL}
                     or
                     3. ${ghprbPullTitle}: ${ghprbPullLink}
                Build URL: ${PROJECT_URL}${BUILD_NUMBER}/
                Full log: ${PROJECT_URL}${BUILD_NUMBER}/consoleText
                Parsed warnings/errors: ${PROJECT_URL}${BUILD_NUMBER}/parsed_console

                Errors:
                ${BUILD_LOG_REGEX, regex=".*ERROR:.* ", linesBefore=0, linesAfter=0, showTruncatedLines=false}
        - archive:
            artifacts: '*.xml,*.json'
            latest-only: true
            allow-empty: true
        - logparser:
            parse-rules: '/var/lib/jenkins/userContent/android.parse'
            unstable-on-warning: false
            fail-on-error: false
        - fingerprint:
            files: 'build/fingerprints/*'
        - email:
            recipients: 'vishal.bhoj@linaro.org fathi.boudra@linaro.org daniel.diaz@linaro.org'
