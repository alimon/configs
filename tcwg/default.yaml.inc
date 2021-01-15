# -*- mode: Yaml -*-

- property:
    name: default-properties
    properties:
      - authorization:
#if RR_tcwg_bmk
          tcwg-benchmark:
            - job-read
            - job-extended-read
            - job-build
            - job-cancel
#else
          anonymous:
            - job-read
            - job-extended-read
          linaro:
            - job-build
            - job-cancel
#endif
      - build-discarder:
          days-to-keep: 30
#if RR_tcwg_cross
          num-to-keep: 10
#else
          num-to-keep: 30
#endif

- scm:
    name: jenkins-scripts
    scm:
      - git:
          url: https://git.linaro.org/toolchain/jenkins-scripts.git
          refspec: +refs/heads/*:refs/remotes/origin/* +refs/changes/*:refs/changes/*
          branches:
            - $scripts_branch
          basedir: jenkins-scripts
          skip-tag: true
          reference-repo: /home/tcwg-buildslave/snapshots-ref/jenkins-scripts.git
          wipe-workspace: false
          clean:
            before: true
          prune: true
