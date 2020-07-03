import argparse
import os
import requests
import sys
import fnmatch
import yaml
import shutil
import itertools
from string import Template
import xmlrpc.client as xmlrpclib

try:
    from urllib.parse import urlsplit
except ImportError:
    from urlparse import urlsplit


# Dump all YAML job definitions as submitted to LAVA
DEBUG_DUMP_JOBDEFS = False

excluded_tests = [
    # Leads to HARD FAULT.
    'tests/kernel/common/test/zephyr/zephyr.bin',
    # Doesn't run, no output.
    'tests/kernel/mem_protect/app_memory/test/zephyr/zephyr.bin',
    'tests/kernel/queue/test_poll/zephyr/zephyr.bin',
    'tests/kernel/fifo/fifo_api/test_poll/zephyr/zephyr.bin',
    # pi benchmark, not covered by current result log parse pattern.
    'tests/kernel/fp_sharing/test_arm/zephyr/zephyr.bin',
    # Endless output, not stopping.
    'tests/kernel/test_build/test_debug/zephyr/zephyr.bin',
    'tests/kernel/test_build/test_runtime_nmi/zephyr/zephyr.bin',
    'tests/kernel/test_build/test_newlib/zephyr/zephyr.bin',
    # Exclude adc_simple as the test is specific to Arduino 101 board.
    'tests/drivers/adc/adc_simple/test/zephyr.bin',
    'tests/drivers/spi_test/test/zephyr.bin',
    'tests/net/route/test/zephyr.bin',
    'tests/net/trickle/test/zephyr.bin',
    'tests/net/context/test/zephyr.bin',
    'tests/net/rpl/test/zephyr.bin',
    'tests/net/socket/udp/test/zephyr.bin',
    'tests/kernel/fp_sharing/test_arm/zephyr.bin',
    'tests/kernel/test_tickless/test/zephyr.bin',
    'tests/kernel/tickless/tickless/test/zephyr.bin',
    'tests/kernel/test_sleep/test/zephyr.bin',
    'tests/kernel/sleep/test/zephyr.bin',
    'tests/kernel/timer/timer_monotonic/test/zephyr.bin',
    'tests/kernel/pthread/test/zephyr.bin',
    'tests/legacy/kernel/test_critical/test/zephyr.bin',
    'tests/legacy/kernel/test_sleep/test/zephyr.bin',
    'tests/ztest/test/base/test_verbose_1/zephyr.bin',
    'tests/kernel/mem_protect/app_memory/test/zephyr.bin',
    'tests/kernel/fatal/test/zephyr.bin',
    'tests/bluetooth/shell/test_nble/zephyr.bin',
]

# Templates base path
template_base_path = 'configs/zephyr-upstream/lava-job-definitions'
# Snapshots base URL
snapshots_url = 'https://snapshots.linaro.org/components/kernel/zephyr'


def file_list(path, fname):
    assert os.path.exists(path), '{} not found'.format(path)
    file_list = []
    for dirpath, dirnames, files in os.walk(path):
        for name in files:
            if fnmatch.fnmatch(name, fname):
                file_list.append(os.path.join(dirpath, name))

    return file_list


def build_only():
    # Parse testcase.yaml to exclude build only tests.
    # testcase.yaml file path example: tests/drivers/build_all/testcase.yaml
    testcases_yaml = file_list('zephyr/tests', 'testcase.yaml')
    build_only_tests = []
    for testcase_yaml in testcases_yaml:
        with open(testcase_yaml, encoding='utf-8') as f:
            data = yaml.safe_load(f)

        try:
            testcase_dir = os.path.dirname(testcase_yaml).split("/", 1)[-1]
            # Example: tests/bluetooth/init/testcase.yaml
            if 'common' in data.keys() and data['common'].get('build_only'):
                for test in data['tests'].keys():
                    build_only_tests.append(os.path.join(testcase_dir, test, 'zephyr/zephyr.bin'))
            else:
                # Eaxmple: tests/drivers/build_all/testcase.yaml
                for test, properties in data['tests'].items():
                    if properties.get('build_only'):
                        build_only_tests.append(os.path.join(testcase_dir, test, 'zephyr/zephyr.bin'))
        except KeyError as e:
            print('ERROR: {} is missing in {}'.format(str(e), testcase_yaml))

    return build_only_tests


def generate_test_list(platform, device_type):
    build_only_tests = build_only()
    fixed_excluded_tests = set(excluded_tests).union(set(build_only_tests))
    print('\n=== tests will be excluded ===')
    print('--- build only tests ---')
    for test in build_only_tests:
        print(test)
    print('--- tests from excluded_tests list ---')
    for test in excluded_tests:
        print(test)

    test_list = file_list('out/{}/tests'.format(platform), 'zephyr.bin')
    shutil.rmtree('out', ignore_errors=True)
    # Test image path example: 'tests/kernel/pthread/test/zephyr.bin'
    test_list = [test.split('/', 2)[-1] for test in test_list]
    # Remove excluded tests.
    test_list = list(set(test_list).difference(fixed_excluded_tests))
    # Exclude benchmarks which require different parse pattern by test.
    test_list = [test for test in test_list if 'benchmark' not in test]
    # Don't run bluetooth test on qemu device.
    if device_type == 'qemu':
        test_list = [test for test in test_list if 'bluetooth' not in test]
    # net test is broken on frdm-kw41z.
    if device_type == 'frdm-kw41z':
        test_list = [test for test in test_list if 'tests/net' not in test]
    print('\n--- final test list ---')
    for test in test_list:
        print(test)

    return test_list

def get_yaml(zephyr_bin_path):
    # Return contents of testcase.yaml file corresponding to the test binary.
    # Test binary path is of form: 'tests/shell/shell/zephyr/zephyr.bin'
    #     and testcase.yaml is located at 'tests/shell', meaning we
    #     should discard the last 3 items.
    path = zephyr_bin_path.split('/')
    assert (len(path) >= 4), "Unexpected directory structure encountered."
    path = path[0:-3]
    path.append("testcase.yaml")
    path.insert(0, "zephyr")
    testcase_yaml = "/".join(path)
    with open(testcase_yaml, encoding="utf-8") as f:
        try:
            data = yaml.safe_load(f)
        except:
            print("ERROR: unable to load %s" % f)
            sys.exit(1)
    
    return data

def permutations_of_regexes(regexes):
    # Create a string with the permutations of all the regular expressions.
    # .* is inserted between each of the expressions in a given permutation,
    # and | is used to separate the permutations.
    # E.g. if we have this set of regular expressions
    #     - dog
    #     - cat
    #     - fish
    # The result would be a string like this (ordering of the permutations might vary)
    # dog.*cat.*fish|cat.*dog.*fish|dog.*fish.*cat|fish.*dog.*cat|fish.*cat.*dog|cat.*fish.*dog
    l = list(itertools.permutations(regexes))
    regex_list = []
    for item in l:
        regex_list.append(".*".join(item))
    return "|".join(regex_list)

def parse_yaml_harness_config(yaml_node):
    # Return a string with the actual regular expression to look for in the LAVA job.
    # We can then use LAVA's interactive test action to look for it.
    if yaml_node.get("harness") == "console":
        config = yaml_node.get("harness_config", {})
        if config.get("type") == "one_line":
            return config["regex"][0]
        elif config.get("type") == "multi_line":
            if "ordered" not in config or config["ordered"] == "true":
                # For ordered regular expressions, we can simply join them into one,
                # while allowing any character in between via (.*)
                return ".*".join(config["regex"])
            else:
                # For non-ordered case, we need to look for all permutations of
                # the regexes, since they can occur in any order.
                return permutations_of_regexes(config["regex"])
    else:
        return None

# Get a node with "harness" directive from testcase.yaml, which is either
# "common" node, or node for a specific test name
def get_section_with_harness(test_path, yaml):
    for key in yaml:
        if key == "common":
            yaml_node = yaml["common"]
            if "harness" in yaml_node:
                return yaml_node
        elif key == "tests":
            path = test_path.split('/')
            if len(path) < 4:
                print("Unexpected directory structure encountered. Aborting...")
                sys.exit(1)
            test_name = path[-3]
            yaml_node = yaml["tests"][test_name]
            if "harness" in yaml_node:
                return yaml_node

    return None

def get_regex(test, yaml):
    # Parse yaml data to extract list of regular expressions to be searched,
    # if present. Otherwise return None.

    yaml_node = get_section_with_harness(test, yaml)
    if not yaml_node:
        return None
    return parse_yaml_harness_config(yaml_node)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--board-name",
                        help="Board name in snapshots URL",
                        dest="board_name",
                        required=True)
    parser.add_argument("--device-type",
                        help="Device type in LAVA",
                        dest="device_type",
                        required=True)
    parser.add_argument("--build-number",
                        help="Build number",
                        dest="build_number",
                        required=True)
    parser.add_argument("--branch-name",
                        help="Branch name for creating snapshots URL",
                        dest="branch_name",
                        required=True)
    parser.add_argument("--qa-server-team",
                        help="Team in QA Reports service",
                        dest="qa_server_team",
                        default=None)
    parser.add_argument("--qa-server-project",
                        help="Project in QA Reports service",
                        dest="qa_server_project",
                        default=None)
    parser.add_argument("--qa-server",
                        help="QA Reports server",
                        dest="qa_server",
                        default="https://qa-reports.linaro.org")
    parser.add_argument("--qa-token",
                        help="QA Reports token",
                        dest="qa_token",
                        default=os.environ.get('QA_REPORTS_TOKEN'))
    parser.add_argument("--direct-to-lava",
                        action='store_true',
                        help="submit to LAVA without using QA server",
                        dest="direct_lava",
                        default=False)
    parser.add_argument("--lava-server",
                        help="LAVA server URL",
                        dest="lava_server",
                        required=True)
    parser.add_argument("--gcc-variant",
                        help="GCC variant",
                        dest="gcc_variant",
                        required=True)
    parser.add_argument("--git-commit",
                        help="git commit ID",
                        dest="git_commit",
                        required=True)
    parser.add_argument("--build-url",
                        help="Jenkins build url",
                        dest="build_url",
                        required=True)
    parser.add_argument("--lava-token",
                        help="LAVA API token. Only necessary when directly using LAVA server instead of QA server",
                        dest="lava_token",
                        default=None)
    parser.add_argument("--lava-user",
                        help="LAVA user. Only necessary when directly using LAVA server instead of QA server",
                        dest="lava_user",
                        default=None)
    parser.add_argument("--bin-suffix",
                        help="Suffix of test binaries",
                        dest="bin_suffix",
                        default="bin")
    args = parser.parse_args()

    template_file_name = "%s/%s/template.yaml" % (template_base_path, args.device_type)
    test_template = None
    if os.path.exists(template_file_name):
        test_template_file = open(template_file_name, encoding="utf-8")
        test_template = test_template_file.read()
        test_template_file.close()
    else:
        print("{} not found!".format(template_file_name))
        sys.exit(1)

    lava_server = args.lava_server
    if not (lava_server.startswith("http://") or lava_server.startswith("https://")):
        lava_server = "https://" + lava_server
    if args.direct_lava:
        lava_server_base = urlsplit(lava_server).netloc + urlsplit(lava_server).path
        lava_user = args.lava_user
        if lava_user is None:
            print("Must provide a LAVA user when using LAVA server.")
            sys.exit(1)
        lava_token = args.lava_token
        if lava_token is None:
            print("Must provide a LAVA token when using LAVA server.")
            sys.exit(1)
    else:
        qa_server_base = args.qa_server
        if not (qa_server_base.startswith("http://") or qa_server_base.startswith("https://")):
            qa_server_base = "https://" + qa_server_base
        qa_server_team = args.qa_server_team
        if qa_server_team is None:
            print("Must provide QA server team when using a QA server.")
            sys.exit(1)
        qa_server_project = args.qa_server_project
        # SQUAD build ID should be unique for each actual build (or results of
        # different actual builds will be mixed on SQUAD side), so well, include
        # build # in it.
        qa_server_build = "{0}-{1}".format(args.git_commit, args.build_number)
        qa_server_env = '{0}-{1}'.format(args.board_name, args.gcc_variant)
        qa_server_api = "%s/api/submitjob/%s/%s/%s/%s" % (
            qa_server_base,
            qa_server_team,
            qa_server_project,
            qa_server_build,
            qa_server_env)
        lava_url_base = "%s://%s/" % (urlsplit(lava_server).scheme, urlsplit(lava_server).netloc)
        headers = {
            "Auth-Token": args.qa_token
        }

    test_url_prefix = "%s/%s/%s/%s/%s/" % (
        snapshots_url, args.branch_name, args.gcc_variant, args.board_name, args.build_number)
    os.chdir(os.getenv('WORKSPACE'))
    print('CWD: {}'.format(os.getcwd()))
    print(os.listdir('.'))

    test_list = generate_test_list(args.board_name, args.device_type)
    tests_submitted = 0
    for test in test_list:
        yaml_config = get_yaml(test)
        harness_section = get_section_with_harness(test, yaml_config)

        # As of now, LAVA lab doesn't have boards with special harnesses,
        # so skip tests which require something beyond basic "console".
        if harness_section and harness_section["harness"] != "console":
            print("Warning: test %s requires harness '%s', skipping" % (
                test, harness_section["harness"]
            ))
            continue

        re = get_regex(test, yaml_config)
        test_name = test.rsplit('/zephyr.bin')[0].replace('/', '-').replace('.', '-')
        if re is None:
            test_action = \
                "    monitors:\n" + \
                "    - name: " + test_name + "\n" + \
                "      start: (tc_start\(\)|starting .*test|Booting Zephyr OS)\n" + \
                "      end: PROJECT EXECUTION\n" + \
                "      pattern: (?P<result>(PASS|FAIL))\s-\s(?P<test_case_id>\w+)\\r\\n\n" + \
                "      fixupdict:\n" + \
                "        PASS: pass\n" + \
                "        FAIL: fail\n"
        else:
            test_action = \
                "    interactive:\n" + \
                "    - name: " + test_name + "\n" + \
                "      prompts: [\"" + re + "\"]\n" + \
                "      script:\n" + \
                "      - command:\n" + \
                "        name: " + test_name + "\n"
        if args.bin_suffix != "bin":
            test = test.rsplit('.', 1)[0] + '.' + args.bin_suffix
        replace_dict = dict(
            # Test name example: kernel-pthread-test
            test_name=test_name,
            test_url="%s%s" % (test_url_prefix, test),
            build_url=args.build_url,
            gcc_variant=args.gcc_variant,
            git_commit=args.git_commit,
            device_type=args.device_type,
            board_name=args.board_name,
            test_action=test_action
        )
        template = Template(test_template)
        lava_job = template.substitute(replace_dict)

        if DEBUG_DUMP_JOBDEFS:
            print(lava_job)

        if args.direct_lava:
            try:
                server = xmlrpclib.ServerProxy("%s://%s:%s@%s" % (urlsplit(lava_server).scheme, lava_user, lava_token, lava_server_base))
                job_id = server.scheduler.submit_job(lava_job)
                print(test + ":", "%s/scheduler/job/%d" % (lava_server, job_id))
                tests_submitted += 1
            except xmlrpclib.ProtocolError as err:
                print(lava_job)
                print("A protocol error occurred")
                print("URL: %s" % err.url)
                print("HTTP/HTTPS headers: %s" % err.headers)
                print("Error code: %d" % err.errcode)
                print("Error message: %s" % err.errmsg)
            except xmlrpclib.Fault as err:
                print(lava_job)
                print("A fault occurred")
                print("Fault code: %d" % err.faultCode)
                print("Fault string: %s" % err.faultString)
        else:
            try:
                data = {
                    "definition": lava_job,
                    "backend": urlsplit(lava_url_base).netloc  # qa-reports backends are named as lava instances
                }
                results = requests.post(qa_server_api, data=data, headers=headers)
                if results.status_code < 300:
                    print(test + ":", "%s/testjob/%s" % (qa_server_base, results.text))
                    tests_submitted += 1
                else:
                    print(lava_job)
                    print("status code: %s" % results.status_code)
                    print(results.text)
            except requests.exceptions.RequestException as err:  # nopep8
                print("QA Reports submission failed")
                print("offending job definition:")
                print(lava_job)
                print("Error code: %d" % err.errcode)
                print("Error message: %s" % err.errmsg)

    print("Total successfully submitted test jobs: %d" % tests_submitted)

if __name__ == "__main__":
    main()
