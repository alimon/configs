# -*- mode: Yaml -*-

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
