#!/usr/bin/python

import base64
import collections
import fileinput
import json
import os
import re
import sys
import urllib2
import xmlrpclib

tests_timeout = {
    'bluetooth-enablement': 7200,
    'bootchart': 800,
    'busybox': 800,
    'cyclictest': 90000,
    'device-tree': 800,
    'e2eaudiotest': 7200,
    'ethernet': 800,
    'gatortests': 1200,
    'kernel-version': 800,
    'leb-basic-graphics': 7200,
    'ltp': 10800,
    'mysql': 800,
    'network-tests-basic': 1200,
    'perf': 800,
    'phpinfo': 800,
    'phpmysql': 800,
    'pwrmgmt': 1200,
    'sdkhelloc': 800,
    'sdkhellocxx': 800,
    'smoke-tests-basic': 1200,
    'toolchain': 800,
    'wifi-enablement': 7200,
}

tests_nano = [
    'device-tree',
    'gatortests',
    'ltp',
    'perf',
    'pwrmgmt',
    'smoke-tests-basic',
    'network-tests-basic',
]


# CI base URL
ci_base_url = 'https://ci.linaro.org/jenkins/job/'
# Snapshots base URL
snapshots_url = 'https://snapshots.linaro.org'

class LAVADeviceBase(object):
    """
    Base class for definition of the device type and target in lava job.
    """

    def __init__(self, name=None):
        self.name = name


class LAVADeviceType(LAVADeviceBase):
    """
    Representation the definition of the device type in lava job.
    """


class LAVADeviceTarget(LAVADeviceBase):
    """
    Representation the definition of the device target in lava job.
    """


def obfuscate_credentials(s):
    return re.sub(r'([^ ]:).+?(@)', r'\1xxx\2', s)


def auth_headers(username, password):
    return 'Basic ' + base64.encodestring('%s:%s' % (username, password))[:-1]


def get_hwpack_type(job_name, hwpack_file_name="Undefined"):
    hwpack_type = job_name.replace('/', ',')
    ret_split = dict(
        token.split('=') for token in hwpack_type.split(',') if '=' in token)
    try:
        return ret_split['hwpack']
    except KeyError, e:
        # If hwpack key is not found, fallback to hwpack file name
        return hwpack_file_name.split('_')[1].split('-')[1]


def get_rootfs_url(distribution, architecture, rootfs_type):
    # Rootfs last successful build number
    ci_url = '%s%s-%s-%s%s%s%s' % \
             (ci_base_url,
              distribution,
              architecture,
              'rootfs/rootfs=',
              rootfs_type,
              ',label=build',
              '/lastSuccessfulBuild/buildNumber')
    request = urllib2.Request(ci_url)
    try:
        response = urllib2.urlopen(request)
    except urllib2.URLError, e:
        if hasattr(e, 'reason'):
            print 'Failed to reach %s.' % ci_url
            print 'Reason: ', e.reason
        elif hasattr(e, 'code'):
            print 'ci.linaro.org could not fulfill the request: %s' % ci_url
            print 'Error code: ', e.code
        sys.exit('Failed to get last successful rootfs build number.')

    rootfs_build_number = '%s' % eval(response.read())

    # Rootfs last successful build timestamp
    ci_url = '%s%s-%s-%s%s%s%s' % \
             (ci_base_url,
              distribution,
              architecture,
              'rootfs/rootfs=',
              rootfs_type,
              ',label=build',
              '/lastSuccessfulBuild/buildTimestamp?format=yyyyMMdd')
    request = urllib2.Request(ci_url)
    try:
        response = urllib2.urlopen(request)
    except urllib2.URLError, e:
        if hasattr(e, 'reason'):
            print 'Failed to reach %s.' % ci_url
            print 'Reason: ', e.reason
        elif hasattr(e, 'code'):
            print 'ci.linaro.org could not fulfill the request: %s' % ci_url
            print 'Error code: ', e.code
        sys.exit('Failed to get last successful rootfs build timestamp.')

    rootfs_build_timestamp = '%s' % eval(response.read())

    rootfs_file_name = 'linaro-utopic-%s-%s-%s.tar.gz' % \
                       (rootfs_type,
                        rootfs_build_timestamp,
                        rootfs_build_number)

    rootfs_url = '%s/%s/%s/%s/%s/%s' % \
                 (snapshots_url,
                  distribution,
                  'images',
                  rootfs_type,
                  rootfs_build_number,
                  rootfs_file_name)

    return rootfs_url, rootfs_build_number


def lava_submit(config, lava_server):
    print config

    skip_lava = os.environ.get('SKIP_LAVA')
    if skip_lava is None:
        # LAVA user
        lava_user = os.environ.get('LAVA_USER')
        if lava_user is None:
            f = open('/var/run/lava/lava-user')
            lava_user = f.read().strip()
            f.close()

        # LAVA token
        lava_token = os.environ.get('LAVA_TOKEN')
        if lava_token is None:
            f = open('/var/run/lava/lava-token')
            lava_token = f.read().strip()
            f.close()

        # LAVA server base URL
        lava_server_root = lava_server.rstrip('/')
        if lava_server_root.endswith('/RPC2'):
            lava_server_root = lava_server_root[:-len('/RPC2')]

        try:
            server_url = \
                'https://{lava_user:>s}:{lava_token:>s}@{lava_server:>s}'
            server = \
                xmlrpclib.ServerProxy(server_url.format(
                    lava_user=lava_user,
                    lava_token=lava_token,
                    lava_server=lava_server))
            lava_job_id = server.scheduler.submit_job(config)
            job_is_single_node = isinstance(lava_job_id, int)
            if job_is_single_node:
                lava_job_details = server.scheduler.job_details(lava_job_id)
                lava_id = lava_job_details['id']
            else:
                lava_job_details = map(lambda sub_id: server.scheduler.job_details(sub_id), lava_job_id)
                lava_id = lava_job_details[0]['id']
            print 'LAVA Job Id: %s, URL: https://%s/scheduler/job/%s' % \
                  (lava_job_id, lava_server_root, lava_id)
            if not job_is_single_node:
                try:
                    lava_sub_jobs = []
                    for details in lava_job_details:
                        lava_job_role = json.loads(details['definition'])['role']
                        lava_sub_jobs.append('%s:%s:%s' % (details['id'], details['sub_id'], lava_job_role))
                    print 'LAVA Sub-Jobs: %s' % ', '.join(lava_sub_jobs)
                except (TypeError, ValueError):
                    # ignore ValueError JSON decode errors in case job is YAML based
                    pass
        except xmlrpclib.ProtocolError, e:
            print 'Error making a LAVA request:', obfuscate_credentials(str(e))
            sys.exit(1)

        json.dump({'lava_url': 'https://' + lava_server_root,
                   'job_id': lava_job_id}, open('lava-job-info', 'w'))
    else:
        print 'LAVA job submission skipped.'

    sys.exit()


def get_job_list():
    job_list = ['CUSTOM_JSON_URL']
    sec_job_prefix = 'CUSTOM_JSON_URL_'

    for var in os.environ.keys():
        if var.startswith(sec_job_prefix):
            job_list.append(var)
    job_list.sort()

    return job_list


def replace(fp, pattern, subst):
    print pattern
    print subst
    for line in fileinput.input(fp, inplace=1):
        if pattern in line:
            line = line.replace(pattern, subst)
        sys.stdout.write(line)
    fileinput.close()


def submit_job_from_url():
    """This routine updates a predefined job with the parameters specific
    to this particular build"""
    job_list = get_job_list()
    for job in job_list:
        lava_job_url = os.environ.get(job)
        if lava_job_url is None:
            print "Error: No CUSTOM_JSON_URL provided"
            return
        jobresource = urllib2.urlopen(lava_job_url)
        jobjson = open('job.json','wb')
        jobjson.write(jobresource.read())
        jobjson.close()
        # Job name, defined by android-build, e.g. linaro-android_leb-panda
        job_name = os.environ.get("JOB_NAME")
        default_frontend_job_name = "~" + job_name.replace("_", "/", 1)
        frontend_job_name = os.environ.get("FRONTEND_JOB_NAME", default_frontend_job_name)

        # Build number, defined by android-build, e.g. 61
        build_number = os.environ.get("BUILD_NUMBER")

        # download base URL, this may differ from job URL if we don't host
        # downloads in Jenkins any more
        download_url = "%s/%s/%s/" % ('%s/android/' % snapshots_url,
                                      frontend_job_name,
                                      build_number)

        # jenkins job name scheme doesn't apply for 96boards jobs so expect
        # download_url to be provided by the job.
        download_url = os.environ.get("DOWNLOAD_URL", download_url)

        # Set the file extension based on the type of artifacts
        artifact_type = os.environ.get("MAKE_TARGETS", "tarball")
        if artifact_type == "droidcore":
            # Check if File extension is already defined
            file_extension = os.environ.get("IMAGE_EXTENSION", "img")
        else:
            file_extension = "tar.bz2"

        boot_subst = "%s%s%s" % (download_url, "/boot.", file_extension)
        system_subst = "%s%s%s" % (download_url, "/system.", file_extension)
        userdata_subst = "%s%s%s" % (download_url, "/userdata.", file_extension)
        cache_subst = "%s%s%s" % (download_url, "/cache.", file_extension)

        replace("job.json", "%%ANDROID_BOOT%%", boot_subst)
        replace("job.json", "%%ANDROID_SYSTEM%%", system_subst)
        replace("job.json", "%%ANDROID_DATA%%", userdata_subst)
        replace("job.json", "%%ANDROID_CACHE%%", cache_subst)
        replace("job.json", "%%ANDROID_META_NAME%%", job_name)
        replace("job.json", "%%JOB_NAME%%", job_name)
        replace("job.json", "%%ANDROID_META_BUILD%%",  build_number)
        replace("job.json", "%%ANDROID_META_URL%%", os.environ.get("BUILD_URL"))
        replace("job.json", "%%BUNDLE_STREAM%%", os.environ.get('LAVA_STREAM', '/private/team/linaro/android-daily/'))
        replace("job.json", "%%WA2_JOB_NAME%%", build_number)
        replace("job.json", "%%DOWNLOAD_URL%%", download_url)
        replace("job.json", "%%GERRIT_CHANGE_NUMBER%%", os.environ.get("GERRIT_CHANGE_NUMBER", ""))
        replace("job.json", "%%GERRIT_PATCHSET_NUMBER%%", os.environ.get("GERRIT_PATCHSET_NUMBER", ""))
        replace("job.json", "%%GERRIT_CHANGE_URL%%", os.environ.get("GERRIT_CHANGE_URL", ""))
        replace("job.json", "%%GERRIT_CHANGE_ID%%", os.environ.get("GERRIT_CHANGE_ID", ""))
        replace("job.json", "%%REFERENCE_BUILD_URL%%", os.environ.get("REFERENCE_BUILD_URL", ""))
        replace("job.json", "%%CTS_MODULE_NAME%%", os.environ.get("CTS_MODULE_NAME", ""))

        # LAVA server URL
        lava_server = os.environ.get('LAVA_SERVER',
                                     'validation.linaro.org/RPC2/')

        with open("job.json", 'r') as fin:
            print fin.read()

        # Inject credentials after the job dump to avoid to leak
        replace("job.json", "%%ART_TOKEN%%", os.environ.get("ART_TOKEN"))
        replace("job.json", "%%ARTIFACTORIAL_TOKEN%%", os.environ.get("ARTIFACTORIAL_TOKEN"))
        replace("job.json", "%%QA_REPORTS_TOKEN%%", os.environ.get("QA_REPORTS_TOKEN"))
        replace("job.json", "%%AP_SSID%%", os.environ.get("AP_SSID"))
        replace("job.json", "%%AP_KEY%%", os.environ.get("AP_KEY"))

        with open("job.json") as fd:
            config = fd.read().strip()
        lava_submit(config=config, lava_server=lava_server)

    sys.exit()


def main():
    '''Script entry point: return some JSON based on calling args.
    We should be called from Jenkins and expect the following to be defined:
    $HWPACK_BUILD_NUMBER $HWPACK_JOB_NAME HWPACK_FILE_NAME $DEVICE_TYPE
    or, alternatively, $TARGET_PRODUCT $JOB_NAME $BUILD_NUMBER $BUILD_URL
    '''

    # LAVA server URL
    lava_server = os.environ.get('LAVA_SERVER',
                                 'validation.linaro.org/RPC2/')

    # CI user
    ci_user = os.environ.get('CI_USER')
    # CI pass
    ci_pass = os.environ.get('CI_PASS')
    if ci_user is not None and ci_pass is not None:
        auth = auth_headers(ci_user, ci_pass)
    else:
        auth = None

    if os.environ.get('TARGET_PRODUCT') is not None:
        submit_job_from_url()

    # Allow to override completely the generated json
    # using file provided by the user
    custom_url = os.environ.get('CUSTOM_JSON_URL')
    if custom_url is None:
        custom_url = os.environ.get('CUSTOM_YAML_URL')
    if custom_url is not None:
        request = urllib2.Request(custom_url)
        if auth:
            request.add_header('Authorization', auth)
        try:
            response = urllib2.urlopen(request)
        except urllib2.URLError, e:
            if hasattr(e, 'reason'):
                print 'Failed to reach %s.' % custom_url
                print 'Reason: ', e.reason
            elif hasattr(e, 'code'):
                print 'ci.linaro.org could not fulfill the request: %s' % \
                      custom_url
                print 'Error code: ', e.code
            sys.exit('Failed to get last successful artifact.')

        if os.environ.get('CUSTOM_JSON_URL') is not None:
            config = json.dumps(json.load(
                response, object_pairs_hook=collections.OrderedDict),
                indent=2, separators=(',', ': '))
        else:
            config = response.read()

        lava_submit(config, lava_server)

    # Name of the hardware pack project
    hwpack_job_name = os.environ.get('HWPACK_JOB_NAME')
    # The hardware pack build number
    hwpack_build_number = os.environ.get('HWPACK_BUILD_NUMBER')
    # Hardware pack file name
    hwpack_file_name = os.environ.get('HWPACK_FILE_NAME', 'Undefined')
    if hwpack_file_name == 'Undefined':
        sys.exit('Hardware pack is not defined.')

    # Device type
    device_type = os.environ.get('DEVICE_TYPE', 'Undefined')
    if device_type == 'Undefined':
        sys.exit('Device type is not defined.')

    # Pre-built image URL
    image_url = os.environ.get('IMAGE_URL', 'Undefined')

    # Hardware pack URL
    hwpack_url = os.environ.get('HWPACK_URL', 'Undefined')

    # Test definitions repository
    git_repo = os.environ.get('GIT_REPO',
                              'git://git.linaro.org/qa/test-definitions.git')

    # Distribution, architecture and hardware pack type
    distribution = os.environ.get('DISTRIBUTION', 'ubuntu')
    architecture = os.environ.get('ARCHITECTURE', 'armhf')
    if hwpack_job_name.startswith('package-and-publish'):
        ret_split = hwpack_job_name.split('-', 3)
        hwpack_type = ret_split[3]
    elif hwpack_job_name.startswith('linux'):
        hwpack_type = get_hwpack_type(hwpack_job_name)
    else:
        ret_split = hwpack_job_name.split('-', 2)
        (distribution, architecture, hwpack_type) = \
            ret_split[0], ret_split[1], ret_split[2]
        hwpack_type = get_hwpack_type(hwpack_job_name, hwpack_file_name)

    # Rootfs type, default is nano-lava
    rootfs_type = os.getenv('ROOTFS_TYPE', 'nano-lava')

    # Bundle stream name
    bundle_stream_name = os.environ.get(
        'BUNDLE_STREAM_NAME',
        '/private/team/linaro/developers-and-community-builds/')

    lava_test_plan = os.environ.get('LAVA_TEST_PLAN')
    if lava_test_plan is None:
        # tests set specific to an image
        tests = tests_nano
    else:
        lava_test_plan = lava_test_plan.strip("'")
        tests = lava_test_plan.split()

    # vexpress doesn't support PM, so disable pwrmgmt
    if device_type in ['vexpress-a9']:
        try:
            tests.remove('pwrmgmt')
        except ValueError:
            pass

    actions = [{'command': 'deploy_linaro_image'}]
    deploy_image_parameters = {}
    metadata = {}

    if image_url == 'Undefined':
        # Convert CI URLs to snapshots URLs
        if hwpack_url == 'Undefined':
            if hwpack_job_name.startswith('package-and-publish'):
                hwpack_job_name_fixup = hwpack_job_name.replace('.', '_')
                hwpack_url = '%s/%s/%s/%s/%s/%s' % \
                             (snapshots_url,
                              'kernel-hwpack',
                              hwpack_job_name_fixup,
                              hwpack_job_name,
                              hwpack_build_number,
                              hwpack_file_name)
            elif hwpack_job_name.startswith('linux'):
                hwpack_url = '%s/%s/%s-%s/%s/%s' % \
                             (snapshots_url,
                              'kernel-hwpack',
                              hwpack_job_name.split('/')[0],
                              hwpack_type,
                              hwpack_build_number,
                              hwpack_file_name)
            else:
                hwpack_url = '%s/%s/%s/%s/%s/%s' % \
                             (snapshots_url,
                              distribution,
                              'hwpacks',
                              hwpack_type,
                              hwpack_build_number,
                              hwpack_file_name)

        (rootfs_url, rootfs_build_number) = get_rootfs_url(distribution,
                                                           architecture,
                                                           rootfs_type)

        deploy_image_parameters['hwpack'] = hwpack_url
        deploy_image_parameters['rootfs'] = rootfs_url
        metadata['rootfs.type'] = rootfs_type
        metadata['rootfs.build'] = rootfs_build_number
    else:
        deploy_image_parameters['image'] = image_url

    metadata['hwpack.type'] = hwpack_type
    metadata['hwpack.build'] = hwpack_build_number
    metadata['distribution'] = distribution

    deploy_image_parameters_url = os.environ.get('DEPLOY_IMAGE_PARAMETERS_URL')
    if deploy_image_parameters_url is not None:
        request = urllib2.Request(deploy_image_parameters_url)
        if auth:
            request.add_header('Authorization', auth)
        try:
            response = urllib2.urlopen(request)
        except urllib2.URLError, e:
            if hasattr(e, 'reason'):
                print 'Failed to reach %s.' % deploy_image_parameters_url
                print 'Reason: ', e.reason
            elif hasattr(e, 'code'):
                print 'ci.linaro.org could not fulfill the request: %s' % \
                      deploy_image_parameters_url
                print 'Error code: ', e.code
            sys.exit('Failed to get last successful artifact.')

        deploy_image_parameters.update(json.load(response, object_pairs_hook=collections.OrderedDict))

    actions[0]['parameters'] = deploy_image_parameters

    metadata_url = os.environ.get('METADATA_URL')
    if metadata_url is not None:
        request = urllib2.Request(metadata_url)
        if auth:
            request.add_header('Authorization', auth)
        try:
            response = urllib2.urlopen(request)
        except urllib2.URLError, e:
            if hasattr(e, 'reason'):
                print 'Failed to reach %s.' % metadata_url
                print 'Reason: ', e.reason
            elif hasattr(e, 'code'):
                print 'ci.linaro.org could not fulfill the request: %s' % \
                      metadata_url
                print 'Error code: ', e.code
            sys.exit('Failed to get last successful artifact.')

        metadata.update(json.load(response, object_pairs_hook=collections.OrderedDict))

    actions[0]['metadata'] = metadata

    if len(tests) == 0:
        actions.append({
            'command': 'boot_linaro_image'
        })

    boot_image_parameters_url = os.environ.get('BOOT_IMAGE_PARAMETERS_URL')
    if boot_image_parameters_url is not None:
        request = urllib2.Request(boot_image_parameters_url)
        if auth:
            request.add_header('Authorization', auth)
        try:
            response = urllib2.urlopen(request)
        except urllib2.URLError, e:
            if hasattr(e, 'reason'):
                print 'Failed to reach %s.' % boot_image_parameters_url
                print 'Reason: ', e.reason
            elif hasattr(e, 'code'):
                print 'ci.linaro.org could not fulfill the request: %s' % \
                      boot_image_parameters_url
                print 'Error code: ', e.code
            sys.exit('Failed to get last successful artifact.')

        boot_image_parameters = json.load(response, object_pairs_hook=collections.OrderedDict)
        if {'command': 'boot_linaro_image'} not in actions:
            actions.append({
                'command': 'boot_linaro_image'
            })
        actions[1]['parameters'] = boot_image_parameters

    if len(tests) > 0:
        if distribution == 'quantal' or distribution == 'raring':
            distribution = 'ubuntu'
        for test in tests:
            test_list = [({'git-repo': git_repo,
                           'testdef': '{distribution:>s}/{test:>s}.yaml'.format(
                               distribution=distribution, test=test)})]

            actions.append({
                'command': 'lava_test_shell',
                'parameters': {
                    'timeout': tests_timeout.get(test, 18000),
                    'testdef_repos': test_list
                }
            })

    actions.append({
        'command': 'submit_results',
        'parameters': {
            'stream': bundle_stream_name,
            'server': '%s%s' % ('https://', lava_server)
        }
    })

    # XXX Global timeout in LAVA is hardcoded to 24h (24 * 60 60)
    # https://bugs.launchpad.net/bugs/1226017
    # Set to 172800s (48h) to workaround the limitation
    # A sane default is 900s (15m)
    config = json.dumps({'timeout': 172800,
                         'actions': actions,
                         'job_name': '%s%s/%s/' % (ci_base_url,
                                                   hwpack_job_name,
                                                   hwpack_build_number),
                         'device_type': device_type,
                         }, indent=2, separators=(',', ': '))

    lava_submit(config, lava_server)


if __name__ == '__main__':
    main()
