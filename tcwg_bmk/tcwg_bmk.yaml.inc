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
    name: run-build-script
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
            build_name="#$BUILD_NUMBER"
#elif PURPOSE_dev
            build_name="#$BUILD_NUMBER-$ci_project/$ci_config"
#endif
            branch_opt=""
            # 1 to skip jenkins-scripts
            i=1
            for c in {components}; do
              eval "b=\$$$${{c}}_branch"
#if PURPOSE_ci
              if [ x"$b" = x"default" ]; then
                eval "b=\$GIT_COMMIT_$i"
              fi
#endif
              if [ x"$b" != x"baseline" ]; then
                build_name="$build_name-$c"
                branch_opt="$branch_opt ==rr[${{c}}_branch] $b"
              fi
              i=$(($i+1))
            done

            ./jenkins-scripts/docker-run.sh \
              --distro $distro \
              --ssh_info true \
              -- \
              ./jenkins-scripts/tcwg_bmk-build.sh \
              %% artifacts/jenkins/manifest.sh \
              --BUILD_URL "$BUILD_URL" \
              --scripts_branch "$scripts_branch" \
              --bmk_branch "$bmk_branch" \
              ==rr[ci_project] $ci_project \
              ==rr[ci_config] $ci_config \
              ==rr[binutils_url] $binutils_url \
              ==rr[gcc_url] $gcc_url \
              ==rr[glibc_url] $glibc_url \
#if TOOLCHAIN_llvm
              ==rr[llvm_url] $llvm_url \
#endif
              $branch_opt \
              ==rr[mode] "jenkins-full" \
              ==rr[update_baseline] "$update_baseline" \
              $extra_build_params &
            res=0 && wait $! || res=$?

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

- builder:
    name: run-bisect-script
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
            echo "christophe.lyon@linaro.org" > artifacts/jenkins/mail-recipients.txt
            echo "Build $BUILD_URL failed" > artifacts/jenkins/mail-body.txt

            ./jenkins-scripts/docker-run.sh \
              --distro $distro \
              --ssh_info true \
              -- \
              ./jenkins-scripts/round-robin-bisect.sh \
              %% artifacts/manifests/bisect.sh \
              --BUILD_URL "$BUILD_URL" \
              --current_project "$current_project" \
              --baseline_branch "$baseline_branch" \
              --bad_branch "$bad_branch" \
              --replay_log "$(pwd)/jenkins-scripts/replay_log" \
              --build_script "./jenkins-scripts/tcwg_bmk-build.sh" \
#if PURPOSE_ci
              --JIRA_PASSWORD "$TCWG_JIRA_PASSWORD" \
#endif
              -- \
              --scripts_branch "$scripts_branch" \
              --bmk_branch "$bmk_branch" \
              ==rr[ci_project] $ci_project \
              ==rr[ci_config] $ci_config \
              ==rr[binutils_url] $binutils_url \
              ==rr[gcc_url] $gcc_url \
              ==rr[glibc_url] $glibc_url \
#if TOOLCHAIN_llvm
              ==rr[llvm_url] $llvm_url \
#endif
              $extra_build_params

            if [ x"$mail_recipients" != x"default" ]; then
              echo "$mail_recipients" > artifacts/jenkins/mail-recipients.txt
            fi

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
