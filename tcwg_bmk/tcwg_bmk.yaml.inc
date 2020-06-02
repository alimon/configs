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



