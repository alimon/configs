# -*- mode: Yaml -*-

#include tcwg/round-robin.yaml.inc
- scm:
    name: bmk-scripts
    scm:
      - git:
          url: https://git.linaro.org/toolchain/bmk-scripts.git
          refspec: +refs/heads/*:refs/remotes/origin/* +refs/changes/*:refs/changes/*
          branches:
            - $bmk_branch
          basedir: bmk-scripts
          skip-tag: true
          reference-repo: /home/tcwg-buildslave/snapshots-ref/bmk-scripts.git
          wipe-workspace: false
          clean:
            before: true
          prune: true

- property:
    name: bmk-properties
    properties:
      - authorization:
          tcwg-benchmark:
            - job-read
            - job-extended-read
            - job-build
            - job-cancel
      - build-discarder:
          days-to-keep: 30
          num-to-keep: 30

- wrapper:
    name: default-wrappers
    wrappers:
      - timeout:
          timeout: '{timeout}'
      - timestamps
      - ssh-agent-credentials:
          # tcwg-buildslave user id
          users:
            - 'e0958a95-204f-4c14-a66c-5e2be6c5d50a'

- publisher:
    name: build-publishers
    publishers:
        - archive:
            artifacts: 'artifacts/**'
            latest-only: false
#if RR_tcwg_gnu
        - email-ext:
            recipients: 'tcwg-gcc@linaro.org'
            aborted: true
            failure: false
            success: false
#endif

- publisher:
    name: bisect-publishers
    publishers:
        - build-publishers
        - email-ext:
            recipients: ${{FILE,path="artifacts/jenkins/mail-recipients.txt"}}
            content-type: text
            body: |
              ${{FILE,path="artifacts/jenkins/mail-body.txt"}}
            failure: true
            success: true
            aborted: true
            send-to:
              - recipients
