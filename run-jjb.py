#!/usr/bin/python

import os
import shutil
import signal
import string
import subprocess
import sys
import xml.etree.ElementTree
from distutils.spawn import find_executable


def findparentfiles(fname):
    filelist = []
    newlist = []
    args = ['grep', '-rl', '--exclude-dir=.git', fname]
    proc = subprocess.Popen(args,
                            stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE,
                            universal_newlines=False,
                            preexec_fn=lambda:
                            signal.signal(signal.SIGPIPE, signal.SIG_DFL))
    data = proc.communicate()[0]
    if proc.returncode != 0:
        return filelist
    for filename in data.splitlines():
        if filename.endswith('.yaml') and '/' not in filename:
            filelist.append(filename)
        else:
            newlist = findparentfiles(filename)
            for tempname in newlist:
                filelist.append(tempname)
    return filelist


jjb_cmd = find_executable('jenkins-jobs') or sys.exit('jenkins-jobs is not found.')
jjb_args = [jjb_cmd]

jjb_user = os.environ.get('JJB_USER')
jjb_password = os.environ.get('JJB_PASSWORD')
if jjb_user is not None and jjb_password is not None:
    jenkins_jobs_ini = ('[job_builder]\n'
                        'ignore_cache=True\n'
                        'keep_descriptions=False\n'
                        '\n'
                        '[jenkins]\n'
                        'user=%s\n'
                        'password=%s\n'
                        'url=https://ci.linaro.org/\n' % (jjb_user, jjb_password))
    with open('jenkins_jobs.ini', 'w') as f:
        f.write(jenkins_jobs_ini)
    jjb_args.append('--conf=jenkins_jobs.ini')

jjb_test_args = list(jjb_args)
jjb_delete_args = list(jjb_args)

# !!! "update" below and through out this file is replaced by "test" (using sed)
# !!! in the sanity-check job.
main_action = 'update'
jjb_args.extend([main_action, 'template.yaml'])
jjb_test_args.extend(['test', '-o', 'out/', 'template.yaml'])
jjb_delete_args.extend(['delete'])

if main_action == 'test':
    # Dry-run, don't delete jobs.
    jjb_delete_args.insert(0, 'echo')

try:
    git_args = ['git', 'diff', '--name-only',
                os.environ.get('GIT_PREVIOUS_COMMIT'),
                os.environ.get('GIT_COMMIT')]
    proc = subprocess.Popen(git_args,
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

filelist = []
files = []
for filename in data.splitlines():
    if filename.endswith('.yaml') and '/' not in filename:
        filelist.append(filename)
    else:
        files = findparentfiles(filename)
        for tempname in files:
            filelist.append(tempname)

# Remove duplicate entries in the list
filelist = list(set(filelist))

for conf_filename in filelist:
    with open(conf_filename) as f:
        buffer = f.read()
        template = string.Template(buffer)
        buffer = template.safe_substitute(
            AUTH_TOKEN=os.environ.get('AUTH_TOKEN'),
            LT_QCOM_KEY=os.environ.get('LT_QCOM_KEY'),
            LAVA_USER=os.environ.get('LAVA_USER'),
            LAVA_TOKEN=os.environ.get('LAVA_TOKEN'))
        with open('template.yaml', 'w') as f:
            f.write(buffer)
        try:
            proc = subprocess.Popen(jjb_args,
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

        try:
            shutil.rmtree('out/', ignore_errors=True)

            proc = subprocess.Popen(jjb_test_args,
                                    stdin=subprocess.PIPE,
                                    stdout=subprocess.PIPE,
                                    universal_newlines=False,
                                    preexec_fn=lambda:
                                    signal.signal(signal.SIGPIPE, signal.SIG_DFL))
            data = proc.communicate()[0]
            if proc.returncode != 0:
                raise ValueError("command has failed with code '%s'" % proc.returncode)

            proc = subprocess.Popen(['ls', 'out/'],
                                    stdin=subprocess.PIPE,
                                    stdout=subprocess.PIPE,
                                    universal_newlines=False,
                                    preexec_fn=lambda:
                                    signal.signal(signal.SIGPIPE, signal.SIG_DFL))
            data = proc.communicate()[0]
            if proc.returncode != 0:
                raise ValueError("command has failed with code '%s'" % proc.returncode)

            for filename in data.splitlines():
                conf_name=os.path.splitext(conf_filename)[0]
                if not filename.startswith(conf_name):
                    raise ValueError("Job name %s does not match the file it is in: %s" % (filename, conf_name))
                try:
                    xmlroot = xml.etree.ElementTree.parse('out/' + filename).getroot()
                    disabled = next(xmlroot.iterfind('disabled')).text
                    if disabled != 'true':
                        continue
                    displayName = next(xmlroot.iterfind('displayName')).text
                    if displayName != 'DELETE ME':
                        continue
                except:
                    continue

                delete_args = list(jjb_delete_args)
                delete_args.extend([filename])
                proc = subprocess.Popen(delete_args,
                                        stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE,
                                        universal_newlines=False,
                                        preexec_fn=lambda:
                                        signal.signal(signal.SIGPIPE, signal.SIG_DFL))
                data = proc.communicate()[0]
                if proc.returncode != 0:
                    raise ValueError("command has failed with code '%s'" % proc.returncode)
                print data
        except (OSError, ValueError) as e:
            raise ValueError("%s" % e)

        shutil.rmtree('out/', ignore_errors=True)
        os.remove('template.yaml')

if os.path.exists('jenkins_jobs.ini'):
    os.remove('jenkins_jobs.ini')
