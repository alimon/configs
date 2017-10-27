import argparse
import os
import requests
import sys
from string import Template

try:
    from urllib.parse import urlsplit
except ImportError:
    from urlparse import urlsplit

excluded_tests = [
    'tests/drivers/spi_test/test/zephyr.bin',
    'tests/drivers/build_all/test_build_sensors_n_z/zephyr.bin',
    'tests/drivers/build_all/test_build_sensors_a_m/zephyr.bin',
    'tests/drivers/build_all/test_build_ethernet/zephyr.bin',
    'tests/drivers/build_all/test_build_drivers/zephyr.bin',
    'tests/drivers/build_all/test_build_sensor_triggers/zephyr.bin',
    'tests/net/route/test/zephyr.bin',
    'tests/net/trickle/test/zephyr.bin',
    'tests/net/context/test/zephyr.bin',
    'tests/net/rpl/test/zephyr.bin',
    'tests/net/all/test/zephyr.bin',
    'tests/net/socket/udp/test/zephyr.bin',
    'tests/net/socket/udp/test/zephyr.bin',
    'tests/kernel/fp_sharing/test_arm/zephyr.bin',
    'tests/kernel/test_tickless/test/zephyr.bin',
    'tests/kernel/tickless/tickless/test/zephyr.bin',
    'tests/kernel/test_sleep/test/zephyr.bin',
    'tests/kernel/sleep/test/zephyr.bin',
    'tests/kernel/timer/timer_monotonic/test/zephyr.bin',
    'tests/kernel/pthread/test/zephyr.bin',
    'tests/kernel/test_build/test_newlib/zephyr.bin',
    'tests/kernel/test_build/test_debug/zephyr.bin',
    'tests/kernel/test_build/test_runtime_nmi/zephyr.bin',
    'tests/legacy/kernel/test_critical/test/zephyr.bin',
    'tests/legacy/kernel/test_sleep/test/zephyr.bin',
]

# Templates base path
template_base_path = 'configs/zephyr-upstream/lava-job-definitions'
# Snapshots base URL
snapshots_url = 'https://snapshots.linaro.org/components/kernel/zephyr'


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
                        required=True)
    parser.add_argument("--qa-server-project",
                        help="Project in QA Reports service",
                        dest="qa_server_project",
                        required=True)
    parser.add_argument("--qa-server",
                        help="QA Reports server",
                        dest="qa_server",
                        default="https://qa-reports.linaro.org")
    parser.add_argument("--qa-token",
                        help="QA Reports token",
                        dest="qa_token",
                        default=os.environ.get('QA_REPORTS_TOKEN'))
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
    parser.add_argument("--test-list",
                        help="test list",
                        dest="test_list",
                        required=True)

    args = parser.parse_args()

    template_file_name = "%s/%s/template.yaml" % (template_base_path, args.device_type)
    test_template = None
    if os.path.exists(template_file_name):
        test_template_file = open(template_file_name, "r")
        test_template = test_template_file.read()
        test_template_file.close()
    else:
        sys.exit(1)

    qa_server_base = args.qa_server
    if not (qa_server_base.startswith("http://") or qa_server_base.startswith("https://")):
        qa_server_base = "https://" + qa_server_base
    qa_server_team = args.qa_server_team
    qa_server_project = args.qa_server_project
    qa_server_build = args.git_commit
    qa_server_env = '{0}-{1}'.format(args.board_name, args.gcc_variant)
    qa_server_api = "%s/api/submitjob/%s/%s/%s/%s" % (
        qa_server_base,
        qa_server_team,
        qa_server_project,
        qa_server_build,
        qa_server_env)
    lava_server = args.lava_server
    if not (lava_server.startswith("http://") or lava_server.startswith("https://")):
        lava_server = "https://" + lava_server
    lava_url_base = "%s://%s/" % (urlsplit(lava_server).scheme, urlsplit(lava_server).netloc)
    test_url_prefix = "%s/%s/%s/%s/%s/" % (
        snapshots_url, args.branch_name, args.gcc_variant, args.board_name, args.build_number)

    headers = {
        "Auth-Token": args.qa_token
    }
    test_list = args.test_list.split()
    # Raw test path example: 'out/qemu_cortex_m3/tests/unit/bluetooth/at/test/zephyr.bin'
    # Desired relative test path example: 'tests/kernel/pthread/test/zephyr.bin'
    test_list = [test.split('/', 2)[-1] for test in test_list]
    test_list = [test for test in test_list if test not in excluded_tests]
    # Exclude benchmarks which require different parse pattern by test.
    test_list = [test for test in test_list if 'benchmarks' not in test]
    # Don't run bluetooth test on qemu device.
    if args.device_type == 'qemu':
        test_list = [test for test in test_list if 'bluetooth' not in test]
    for test in test_list:
        replace_dict = dict(
            # Test name example: kernel-pthread-test
            test_name=test.rsplit('/zephyr.bin')[0].replace('/', '-'),
            test_url="%s%s" % (test_url_prefix, test),
            build_url=args.build_url,
            gcc_variant=args.gcc_variant,
            git_commit=args.git_commit,
            device_type=args.device_type,
            board_name=args.board_name
        )
        template = Template(test_template)
        lava_job = template.substitute(replace_dict)
        try:
            data = {
                "definition": lava_job,
                "backend": urlsplit(lava_url_base).netloc  # qa-reports backends are named as lava instances
            }
            results = requests.post(qa_server_api, data=data, headers=headers)
            if results.status_code < 300:
                print("%s/testjob/%s" % (qa_server_base, results.text))
            else:
                print(results.status_code)
                print(results.text)
        except xmlrpclib.ProtocolError as err:
            print("QA Reports submission failed")
            print("offending job definition:")
            print(lava_job)
            print("Error code: %d" % err.errcode)
            print("Error message: %s" % err.errmsg)


if __name__ == "__main__":
    main()
