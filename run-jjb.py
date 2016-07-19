#!/usr/bin/python

import os
import shutil
import signal
import string
import subprocess
import sys
from distutils.spawn import find_executable

jjb_cmd = find_executable('jenkins-job-builder') or sys.exit('jenkins-job-builder is not found.')

try:
    arguments = ['git', 'diff', '--name-only',
                 os.environ.get('GIT_PREVIOUS_COMMIT'),
                 os.environ.get('GIT_COMMIT')]
    proc = subprocess.Popen(arguments,
                            stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE,
                            universal_newlines=False,
                            preexec_fn=lambda:
                            signal.signal(signal.SIGPIPE, signal.SIG_DFL))
except (OSError, ValueError) as e:
    raise ValueError("%s" % e)

data = proc.communicate()[0]
if proc.returncode != 0:
    raise ValueError("command has failed with code '%s'" % proc.returncode)

for conf_filename in data.splitlines():
    if conf_filename.endswith('.yaml') and '/' not in conf_filename:
        with open(conf_filename) as f:
            buffer = f.read()
            template = string.Template(buffer)
        buffer = template.safe_substitute(
            PUBLISH_KEY=os.environ.get('PUBLISH_KEY') or
                        sys.exit('Key is not defined.'),
            ART_METRICS_TOKEN=os.environ.get('ART_METRICS_TOKEN'),
            ART_TOKEN=os.environ.get('ART_TOKEN'),
            ART_TOKEN_ART_REPORTS=os.environ.get('ART_TOKEN_ART_REPORTS'),
            ART_TOKEN_ANDROID_REPORTS=os.environ.get('ART_TOKEN_ANDROID_REPORTS'),
            AUTH_TOKEN=os.environ.get('AUTH_TOKEN'),
            DB_TOKEN=os.environ.get('DB_TOKEN'),
            PRIVATE_KEY=os.environ.get('PRIVATE_KEY'),
            COVERITY_TOKEN_ODP=os.environ.get('COVERITY_TOKEN_ODP'),
            COVERITY_TOKEN_ODP_DPDK=os.environ.get('COVERITY_TOKEN_ODP_DPDK'),
            COVERITY_TOKEN_ODP_KS2=os.environ.get('COVERITY_TOKEN_ODP_KS2'),
            COVERITY_TOKEN_ODP_NETMAP=os.environ.get('COVERITY_TOKEN_ODP_NETMAP'),
            LT_QCOM_KEY=os.environ.get('LT_QCOM_KEY'),
            LT_QUALCOMM_PRIVATE_KEY=os.environ.get('LT_QUALCOMM_PRIVATE_KEY'),
            LAVA_USER=os.environ.get('LAVA_USER'),
            LAVA_TOKEN=os.environ.get('LAVA_TOKEN'))
        with open('template.yaml', 'w') as f:
            f.write(buffer)
        try:
            arguments = [jjb_cmd, 'update', 'template.yaml']
            # arguments = [jjb_cmd, 'test', conf_filename, '-o', 'out']
            proc = subprocess.Popen(arguments,
                                    stdin=subprocess.PIPE,
                                    stdout=subprocess.PIPE,
                                    universal_newlines=False,
                                    preexec_fn=lambda:
                                    signal.signal(signal.SIGPIPE, signal.SIG_DFL))
        except (OSError, ValueError) as e:
            raise ValueError("%s" % e)

        data = proc.communicate()[0]
        if proc.returncode != 0:
            raise ValueError("command has failed with code '%s'" % proc.returncode)

        os.remove('template.yaml')
        #shutil.rmtree('out')
