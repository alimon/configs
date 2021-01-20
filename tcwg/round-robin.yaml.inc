# -*- mode: Yaml -*-

#include tcwg/default.yaml.inc

- parameter:
    name: default-parameters
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
          name: extra_build_params
          default: ""
          description: "Extra parameters to pass to the build script"
      - string:
          name: mail_recipients
          default: default
          description: "Comma-separated list of email recipients; use 'default' unless testing"
      - string:
          name: distro
          default: '{distro}'
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

#if RR_tcwg_bmk
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
#endif

- parameter:
    name: component-parameters
    parameters:
      - string:
          name: '{component}_url'
          default: '{url}'
          description: "{component} git URL"
      - string:
          name: '{component}_branch'
          default: '{branch}'
          description: "{component} branch or sha1 to build, or 'baseline'"

- parameter:
    name: build-parameters
    parameters:
#if COMPONENTS_binutils
      - component-parameters:
          component: binutils
          url: '{binutils_url}'
          branch: '{default_branch}'
#endif
#if COMPONENTS_gcc
      - component-parameters:
          component: gcc
          url: '{gcc_url}'
          branch: '{default_branch}'
#endif
#if COMPONENTS_glibc
      - component-parameters:
          component: glibc
          url: '{glibc_url}'
          branch: '{default_branch}'
#endif
#if COMPONENTS_newlib
      - component-parameters:
          component: newlib
          url: '{newlib_url}'
          branch: '{default_branch}'
#endif
#if COMPONENTS_linux
      - component-parameters:
          component: linux
          url: '{linux_url}'
          branch: '{default_branch}'
#endif
#if COMPONENTS_llvm
      - component-parameters:
          component: llvm
          url: '{llvm_url}'
          branch: '{default_branch}'
#endif
#if COMPONENTS_qemu
      - component-parameters:
          component: qemu
          url: '{qemu_url}'
          branch: '{default_branch}'
#endif
      - choice:
          name: update_baseline
          choices:
            - update
            - reset
            - init
            - push
          description: "What to do with baseline in this build"
      - default-parameters:
          ci_project: '{ci_project}'
          ci_config: '{ci_config}'
          distro: '{distro}'

- scm:
    name: component-scm
    scm:
        - git:
            url: '{url}'
            branches:
              - 'refs/heads/{branch}'
            basedir: '{component}'
            skip-tag: true
            reference-repo: '/home/tcwg-buildslave/snapshots-ref/{reference}'
            wipe-workspace: false
            clean:
              before: true
            prune: true

# SCMs must start with jenkins-scripts and then be ordered alphabetically.
# Same alphabetical order must be followed in .def files.  The reason behind
# this is that jenkins sets $GIT_COMMIT to sha1 of jenkins-scripts, and then
# sets $GIT_COMMIT_1, $GIT_COMMIT_2, etc. to sha1s of component SCM /in the
# order that they are declared here/.
- scm:
    name: build-scms
    scm:
      - jenkins-scripts
#if PURPOSE_ci
#if COMPONENTS_binutils
      - component-scm:
          component: binutils
          url: '{binutils_url}'
          branch: '{binutils_branch}'
          reference: binutils-gdb.git
#endif
#if COMPONENTS_gcc
      - component-scm:
          component: gcc
          url: '{gcc_url}'
          branch: '{gcc_branch}'
          reference: gcc.git
#endif
#if COMPONENTS_glibc
      - component-scm:
          component: glibc
          url: '{glibc_url}'
          branch: '{glibc_branch}'
          reference: glibc.git
#endif
#if COMPONENTS_newlib
      - component-scm:
          component: newlib
          url: '{newlib_url}'
          branch: '{newlib_branch}'
          reference: newlib.git
#endif
#if COMPONENTS_linux
      - component-scm:
          component: linux
          url: '{linux_url}'
          branch: '{linux_branch}'
          reference: linux.git
#endif
#if COMPONENTS_llvm
      - component-scm:
          component: llvm
          url: '{llvm_url}'
          branch: '{llvm_branch}'
          reference: llvm-project.git
#endif
#if COMPONENTS_qemu
      - component-scm:
          component: qemu
          url: '{qemu_url}'
          branch: '{qemu_branch}'
          reference: qemu.git
#endif
#endif /* PURPOSE_ci */
#if RR_tcwg_bmk
      - bmk-scripts
#endif

- wrapper:
    name: build-wrappers
    wrappers:
      - timeout:
          timeout: '{timeout}'
      - timestamps
      - ssh-agent-credentials:
          # tcwg-buildslave user id
          users:
            - 'e0958a95-204f-4c14-a66c-5e2be6c5d50a'

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

- builder:
    name: run-build
    builders:
      - shell:
          command: |
            #!/bin/bash
            set -ex
            # Delete artifacts now to avoid re-using stale artifacts if
            # below docker-run.sh fails to start up a container.
            rm -rf artifacts/
            mkdir -p artifacts/jenkins

            dryruncmd=""
#if RR_tcwg_gcc
            # Don't run these known-bad configurations.
            case {target}-{type_of_test} in
              aarch64-bootstrap_profiled|\
              aarch64-bootstrap_profiled_lto|\
              aarch64-bootstrap_profiled_lto_lean|\
              aarch64-check_bootstrap_lto|\
              arm-bootstrap_profiled|\
              arm-bootstrap_profiled_lto*|\
              arm-check_bootstrap_lto)
                echo "Known bad configuration, not running."
                echo "Would have run:"
                # So we know it wasn't an infrastructure failure
                touch artifacts/failures
                dryruncmd="echo"
                ;;
            esac
#endif

#if PURPOSE_ci
            build_name="#$BUILD_NUMBER"
#elif PURPOSE_dev
            build_name="#$BUILD_NUMBER-$ci_project/$ci_config"
#endif
            branch_opt=""
            # 1 to skip jenkins-scripts
            i=1
            for c in {components}; do
              eval "u=\$$$${{c}}_url"
              eval "b=\$$$${{c}}_branch"
#if PURPOSE_ci
              if [ x"$b" = x"default" ]; then
                eval "b=\$GIT_COMMIT_$i"
              fi
              i=$(($i+1))
#endif
              if [ x"$b" != x"baseline" ]; then
                build_name="$build_name-$c"
                branch_opt="$branch_opt ==rr[${{c}}_url] $u ==rr[${{c}}_branch] $b"
              fi
            done

            $dryruncmd \
            ./jenkins-scripts/docker-run.sh \
              --distro $distro \
#if RR_tcwg_bmk
              --ssh_info true \
#elif RR_tcwg_binutils || RR_tcwg_gcc
              --arch {docker_arch} \
              --node $NODE_NAME \
#endif
              -- \
              ./jenkins-scripts/{build_script} \
              %% artifacts/jenkins/manifest.sh \
              ==rr[ci_project] $ci_project \
              ==rr[ci_config] $ci_config \
              $extra_build_params \
#if RR_tcwg_bmk
              --bmk_branch "$bmk_branch" \
#endif
              --scripts_branch "$scripts_branch" \
              $branch_opt \
              ==rr[mode] "jenkins-full" \
              ==rr[update_baseline] "$update_baseline" \
              --BUILD_URL "$BUILD_URL" &
            res=0 && wait $! || res=$?

            # If we didn't run the docker command
            if [ -n "$dryruncmd" ]; then
              # Mark build unstable aka a skipped config
              exit 125
            fi

            if [ $res != 0 ]; then
              touch artifacts/failures
            fi

            if [ -e artifacts/results ]; then
              build_name="$build_name-R$(tail -n1 artifacts/results)"
            fi
            if [ x"$update_baseline" != x"update" ]; then
              build_name="$build_name-$update_baseline"
            fi
            if [ -f artifacts/trigger-bisect ]; then
              build_name="$build_name-trigger-bisect"
            fi
            echo "$build_name" > artifacts/jenkins/build-name
          unstable-return: 125
      - conditional-step:
          # Only run if above succeeded
          # Meaning we did not skip a bad config
          # (a failed build is indicated by artifacts/failures)
          condition-kind: current-status
          steps:
            - trigger-followup-builds:
                rr_project: '{rr_project}'
                ci_project_config: '{ci_project_config}'
            - shell: |
                #!/bin/bash
                if [ -f artifacts/failures ]; then
                  exit 1
                fi

- publisher:
    name: build-publishers
    publishers:
        - archive:
            artifacts: 'artifacts/**'
            latest-only: false

- parameter:
    name: bisect-parameters
    parameters:
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
      - default-parameters:
          ci_project: '{ci_project}'
          ci_config: '{ci_config}'
          distro: '{distro}'

- wrapper:
    name: bisect-wrappers
    wrappers:
      - build-wrappers:
          timeout: '{timeout}'
#if PURPOSE_ci
      - credentials-binding:
          - text:
              credential-id: TCWG_JIRA_PASSWORD
              variable: TCWG_JIRA_PASSWORD
#endif

- builder:
    name: run-bisect
    builders:
      - shell:
          command: |
            #!/bin/bash
            set -ex
            # Delete artifacts now to avoid re-using stale artifacts if
            # below docker-run.sh fails to start up a container.
            rm -rf artifacts/
            mkdir -p artifacts/jenkins
#if PURPOSE_ci
            build_name="#$BUILD_NUMBER-$current_project"
#elif PURPOSE_dev
            build_name="#$BUILD_NUMBER-$ci_project/$ci_config-$current_project"
#endif
            echo "$build_name" > artifacts/jenkins/build-name
            # artifacts/jenkins/mail-*.txt will be overwritten in successful builds.
#if RR_tcwg_bmk
            echo "christophe.lyon@linaro.org" > artifacts/jenkins/mail-recipients.txt
#elif RR_tcwg_binutils || RR_tcwg_gcc
            echo "prathamesh.kulkarni@linaro.org,tcwg-gcc@linaro.org" > artifacts/jenkins/mail-recipients.txt
#elif RR_tcwg_kernel
            echo "maxim.kuvyrkov@linaro.org" > artifacts/jenkins/mail-recipients.txt
#endif
            echo "Build $BUILD_URL failed" > artifacts/jenkins/mail-body.txt

            ./jenkins-scripts/docker-run.sh \
              --distro $distro \
#if RR_tcwg_bmk
              --ssh_info true \
#elif RR_tcwg_binutils || RR_tcwg_gcc
              --arch {docker_arch} \
              --node $NODE_NAME \
#endif
              -- \
              ./jenkins-scripts/round-robin-bisect.sh \
              %% artifacts/manifests/bisect.sh \
              --BUILD_URL "$BUILD_URL" \
              --current_project "$current_project" \
              --bad_url "$bad_url" \
              --bad_branch "$bad_branch" \
              --replay_log "$(pwd)/jenkins-scripts/replay_log" \
              --build_script "./jenkins-scripts/{build_script}" \
#if PURPOSE_ci
              --JIRA_PASSWORD "$TCWG_JIRA_PASSWORD" \
#endif
              -- \
              ==rr[ci_project] $ci_project \
              ==rr[ci_config] $ci_config \
              $extra_build_params \
#if RR_tcwg_bmk
              --bmk_branch "$bmk_branch" \
#endif
              --scripts_branch "$scripts_branch"

            if [ x"$mail_recipients" != x"default" ]; then
              echo "$mail_recipients" > artifacts/jenkins/mail-recipients.txt
            fi
      - trigger-followup-builds:
          rr_project: '{rr_project}'
          ci_project_config: '{ci_project_config}'

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
