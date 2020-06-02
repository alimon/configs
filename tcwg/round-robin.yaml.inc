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
