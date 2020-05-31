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
      - choice:
          name: update_baseline
          choices:
            - update
            - reset
            - init
            - push
          description: "What to do with baseline in this build"
      - default-parameters

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
#if RR_tcwg_gnu
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
#elif RR_tcwg_gnu
              --arch {docker_arch} \
              --node $NODE_NAME \
#endif
              -- \
              ./jenkins-scripts/#{RR}-build.sh \
              %% artifacts/jenkins/manifest.sh \
              --BUILD_URL "$BUILD_URL" \
              --scripts_branch "$scripts_branch" \
#if RR_tcwg_bmk
              --bmk_branch "$bmk_branch" \
#endif
              ==rr[ci_project] $ci_project \
              ==rr[ci_config] $ci_config \
              $branch_opt \
              ==rr[mode] "jenkins-full" \
              ==rr[update_baseline] "$update_baseline" \
              $extra_build_params &
            res=0 && wait $! || res=$?

            # If we didn't run the docker command
            if [ -n "$dryruncmd" ]; then
              # Mark build unstable aka a skipped config
              exit 100
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
              build_name="$build_name-bisect"
            fi
            echo "$build_name" > artifacts/jenkins/build-name
          unstable-return: 100
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
#elif RR_tcwg_gnu
            echo "prathamesh.kulkarni@linaro.org,tcwg-gcc@linaro.org" > artifacts/jenkins/mail-recipients.txt
#elif RR_tcwg_kernel
            echo "maxim.kuvyrkov@linaro.org" > artifacts/jenkins/mail-recipients.txt
#endif
            echo "Build $BUILD_URL failed" > artifacts/jenkins/mail-body.txt

            ./jenkins-scripts/docker-run.sh \
              --distro $distro \
#if RR_tcwg_bmk
              --ssh_info true \
#endif
              -- \
              ./jenkins-scripts/round-robin-bisect.sh \
              %% artifacts/manifests/bisect.sh \
              --BUILD_URL "$BUILD_URL" \
              --current_project "$current_project" \
              --bad_url "$bad_url" \
              --bad_branch "$bad_branch" \
              --replay_log "$(pwd)/jenkins-scripts/replay_log" \
              --build_script "./jenkins-scripts/tcwg_bmk-build.sh" \
#if PURPOSE_ci
              --JIRA_PASSWORD "$TCWG_JIRA_PASSWORD" \
#endif
              -- \
              --scripts_branch "$scripts_branch" \
#if RR_tcwg_bmk
              --bmk_branch "$bmk_branch" \
#endif
              ==rr[ci_project] $ci_project \
              ==rr[ci_config] $ci_config \
              $extra_build_params

            if [ x"$mail_recipients" != x"default" ]; then
              echo "$mail_recipients" > artifacts/jenkins/mail-recipients.txt
            fi
      - trigger-followup-builds:
          rr_project: '{rr_project}'
          ci_project_config: '{ci_project_config}'

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
