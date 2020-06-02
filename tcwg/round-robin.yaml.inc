# -*- mode: Yaml -*-

#if COMPONENTS_llvm
- scm:
    name: clang-scm
    scm:
        - git:
            url: '{llvm_url}'
            branches:
              - 'refs/heads/{llvm_branch}'
            basedir: llvm
            skip-tag: true
            reference-repo: /home/tcwg-buildslave/snapshots-ref/llvm-project.git
            wipe-workspace: false
            clean:
              before: true
            prune: true
#endif
#if COMPONENTS_binutils
- scm:
    name: binutils-scm
    scm:
        - git:
            url: '{binutils_url}'
            branches:
              - 'refs/heads/{binutils_branch}'
            basedir: binutils
            skip-tag: true
            reference-repo: /home/tcwg-buildslave/snapshots-ref/binutils-gdb.git
            wipe-workspace: false
            clean:
              before: true
            prune: true
#endif
#if COMPONENTS_gcc
- scm:
    name: gcc-scm
    scm:
        - git:
            url: '{gcc_url}'
            branches:
              - 'refs/heads/{gcc_branch}'
            basedir: gcc
            skip-tag: true
            reference-repo: /home/tcwg-buildslave/snapshots-ref/gcc.git
            wipe-workspace: false
            clean:
              before: true
            prune: true
#endif
#if COMPONENTS_glibc
- scm:
    name: glibc-scm
    scm:
        - git:
            url: '{glibc_url}'
            branches:
              - 'refs/heads/{glibc_branch}'
            basedir: glibc
            skip-tag: true
            reference-repo: /home/tcwg-buildslave/snapshots-ref/glibc.git
            wipe-workspace: false
            clean:
              before: true
            prune: true
#endif
#if COMPONENTS_linux
- scm:
    name: linux-scm
    scm:
        - git:
            url: '{linux_url}'
            branches:
              - 'refs/heads/{linux_branch}'
            basedir: linux
            skip-tag: true
            reference-repo: /home/tcwg-buildslave/snapshots-ref/linux.git
            wipe-workspace: false
            clean:
              before: true
            prune: true
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

- parameter:
    name: default-parameters
    parameters:
      - string:
          name: extra_build_params
          default: ""
          description: "Extra parameters to pass to the build script"
      - string:
          name: mail_recipients
          default: default
          description: "Comma-separated list of email recipients; use 'default' unless testing"
      - string:
          name: distro
          default: bionic
          description: 'Distro image to use'
      - string:
          name: scripts_branch
          default: master
          description: 'Scripts revision to use'
#if RR_tcwg_bmk
      - string:
          name: bmk_branch
          default: master
          description: 'Benchmark scripts revision to use'
#endif


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
              echo "mail_recipients=$mail_recipients" >> $i
              echo "distro=$distro" >> $i
              echo "scripts_branch=$scripts_branch" >> $i
#if RR_tcwg_bmk
              echo "bmk_branch=$bmk_branch" >> $i
#endif
            fi
          done
      - trigger-builds:
          - project: '{rr_project}-build-{ci_project_config}'
            parameter-factories:
              - factory: filebuild
                file-pattern: artifacts/trigger-build-*
          - project: '{rr_project}-bisect-{ci_project_config}'
            property-file: artifacts/trigger-bisect

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
          description: "CI configuration ID"
#if COMPONENTS_binutils
      - string:
          name: binutils_url
          default: '{binutils_url}'
          description: "binutils git URL"
      - string:
          name: binutils_branch
          default: '{default_branch}'
          description: "binutils branch or sha1 to build, or 'baseline'"
#endif
#if COMPONENTS_gcc
      - string:
          name: gcc_url
          default: '{gcc_url}'
          description: "gcc git URL"
      - string:
          name: gcc_branch
          default: '{default_branch}'
          description: "gcc branch or sha1 to build, or 'baseline'"
#endif
#if COMPONENTS_glibc
      - string:
          name: glibc_url
          default: '{glibc_url}'
          description: "glibc git URL"
      - string:
          name: glibc_branch
          default: '{default_branch}'
          description: "glibc branch or sha1 to build, or 'baseline'"
#endif
#if COMPONENTS_llvm
      - string:
          name: llvm_url
          default: '{llvm_url}'
          description: "llvm git URL"
      - string:
          name: llvm_branch
          default: '{default_branch}'
          description: "llvm branch or sha1 to build, or 'baseline'"
#endif
#if COMPONENTS_linux
      - string:
          name: linux_url
          default: '{linux_url}'
          description: "linux git URL"
      - string:
          name: linux_branch
          default: default
          description: "linux branch or sha1 to build"
#endif
      - choice:
          name: update_baseline
          choices:
            - update
            - reset
            - init
            - push
          description: "What to do with baseline in this build"
      - default-parameters

- parameter:
    name: bisect-parameters
    parameters:
      - string:
          name: ci_project
          default: '{ci_project}'
          description: "CI project ID; used as namespace for git branches"
      - string:
          name: ci_config
          default: '{ci_config}'
          description: "CI configuration ID"
      - string:
          name: current_project
          default: ""
          description: "Project to bisect"
      - string:
          name: bad_url
          default: ""
          description: "Bad git URL"
      - string:
          name: bad_branch
          default: ""
          description: "Bad branch or sha1"
      - file:
          name: jenkins-scripts/replay_log
          description: "Replay part of bisect using provided bisect log"
      - default-parameters
