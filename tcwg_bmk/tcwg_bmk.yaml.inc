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

- parameter:
    name: build-parameters
    parameters:
      - string:
          name: ci_project
          default: '{ci_project}'
          description: "CI project ID; used as namespace for git branches"
      - string:
          name: ci_config
          default: '{ci_config}'
          description: "CI configuration ID: #{TOOLCHAIN}-{{toolchain_ver}}-{{target}}-{{bmk}}-{{cflags}}"
      - string:
          name: binutils_url
          default: '{binutils_url}'
          description: "binutils git URL"
      - string:
          name: binutils_branch
          default: '{default_branch}'
          description: "binutils branch or sha1 to build, or 'baseline'"
      - string:
          name: gcc_url
          default: '{gcc_url}'
          description: "gcc git URL"
      - string:
          name: gcc_branch
          default: '{default_branch}'
          description: "gcc branch or sha1 to build, or 'baseline'"
      - string:
          name: glibc_url
          default: '{glibc_url}'
          description: "glibc git URL"
      - string:
          name: glibc_branch
          default: '{default_branch}'
          description: "glibc branch or sha1 to build, or 'baseline'"
#if TOOLCHAIN_llvm
      - string:
          name: llvm_url
          default: '{llvm_url}'
          description: "llvm git URL"
      - string:
          name: llvm_branch
          default: '{default_branch}'
          description: "llvm branch or sha1 to build, or 'baseline'"
#endif
- parameter:
    name: bmk-parameters
    parameters:
      - string:
          name: extra_build_params
          default: ""
          description: "Extra parameters to pass to the build script"
      - default-parameters
      - string:
          name: bmk_branch
          default: master
          description: 'Benchmark scripts revision to use'

- builder:
    name: trigger-followup-builds
    builders:
      - build-name-setter:
          name: 'artifacts/jenkins/build-name'
          file: true
      - shell: |
          #!/bin/bash
          set -ex
          for i in artifacts/trigger-build-* artifacts/trigger-bisect; do
            if [ -f $i ]; then
              echo "ci_project=$ci_project" >> $i
              echo "ci_config=$ci_config" >> $i
              echo "binutils_url=$binutils_url" >> $i
              echo "gcc_url=$gcc_url" >> $i
              echo "glibc_url=$glibc_url" >> $i
#if TOOLCHAIN_llvm
              echo "llvm_url=$llvm_url" >> $i
#endif
              echo "mail_recipients=$mail_recipients" >> $i
              echo "distro=$distro" >> $i
              echo "scripts_branch=$scripts_branch" >> $i
              echo "bmk_branch=$bmk_branch" >> $i
            fi
          done
      - trigger-builds:
          - project: '{rr_project}-build-{ci_project_config}'
            parameter-factories:
              - factory: filebuild
                file-pattern: artifacts/trigger-build-*
          - project: '{rr_project}-bisect-{ci_project_config}'
            property-file: artifacts/trigger-bisect