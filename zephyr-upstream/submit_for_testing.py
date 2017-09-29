import argparse
import os
import requests
import sys
from string import Template

try:
    from urllib.parse import urlsplit
except ImportError:
    from urlparse import urlsplit


tests = [
    "kernel/alert/test_alert_api/test",
    "kernel/lifo/test_lifo_api/test",
    "kernel/multilib/test",
    "kernel/critical/test",
    "kernel/sprintf/test",
    "kernel/ipm/test",
    "kernel/context/test",
    "kernel/fifo/test_fifo_api/test",
    "kernel/mem_pool/test_mpool_options/test_mpool_split_defrag",
    "kernel/mem_pool/test_mpool_options/test_mpool_split_only",
    "kernel/mem_pool/test_mpool_options/test_mpool_defrag_split",
    "kernel/mem_pool/test_mpool/test",
    "kernel/mem_pool/test_mpool_concept/test",
    "kernel/mem_pool/test_mpool_threadsafe/test",
    "kernel/mem_pool/test_mpool_api/test",
    "kernel/timer/timer_monotonic/test",
    "kernel/timer/timer_api/test",
    "kernel/msgq/msgq_api/test",
    "kernel/threads_lifecycle/thread_init/test",
    "kernel/threads_lifecycle/lifecycle_api/test",
    "kernel/common/test",
    "kernel/queue/test",
    "kernel/libs/test",
    "kernel/workq/workq_api/test",
    "kernel/errno/test",
    "kernel/threads_customdata/cdata_api/test",
    "kernel/stack/stack_api/test",
    "kernel/profiling/profiling_api/test",
    "kernel/irq_offload/test",
    "kernel/stackprot/test",
    "kernel/systhreads/test",
    "kernel/mbox/mbox_api/test",
    "kernel/gen_isr_table/test",
    "kernel/xip/test",
    "kernel/semaphore/sema_api/test",
    "kernel/mem_heap/mheap_api_concept/test",
    "kernel/mem_slab/test_mslab/test",
    "kernel/mem_slab/test_mslab_threadsafe/test",
    "kernel/mem_slab/test_mslab_api/test",
    "kernel/mem_slab/test_mslab_concept/test",
    "kernel/threads_scheduling/schedule_api/test",
    "kernel/mutex/mutex_api/test",
    "kernel/mutex/mutex/test",
    "kernel/poll/test",
    "kernel/pipe/test_pipe_api/test",
    "kernel/arm_irq_vector_table/test",
    "kernel/arm_runtime_nmi/test",
    "net/buf/test",
    "net/lib/mqtt_packet/test",
    "net/lib/dns_packet/test",
    "net/lib/http_header_fields/test",
    "ztest/test/base/test_verbose_0",
    "ztest/test/base/test_verbose_1",
    "ztest/test/base/test_verbose_2",
    "crypto/test_ctr_prng/test",
    "crypto/test_aes/test",
    "crypto/test_ecc_dh/test",
    "crypto/test_sha256/test",
    "crypto/test_mbedtls/test",
    "bluetooth/bluetooth/test",
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

    args = parser.parse_args()

    test_url_suffix = "/zephyr.bin"
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
    qa_server_env = args.board_name
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
    test_url_prefix = "%s/%s/%s/%s/%s/tests/" % (
        snapshots_url, args.branch_name, args.gcc_variant, args.board_name, args.build_number)

    headers = {
        "Auth-Token": args.qa_token
    }
    for test in tests:
        replace_dict = dict(
            test_name=test,
            test_url="%s%s%s" % (test_url_prefix, test, test_url_suffix),
            build_url=args.build_url,
            gcc_variant=args.gcc_variant,
            git_commit=args.git_commit,
            device_type=args.device_type,
            board_name=args.board_name
        )
        if replace_dict['test_name'].endswith("/test"):
            replace_dict.update(
                {'test_name': "".join(replace_dict['test_name'].rsplit("/test", 1))}
            )
        replace_dict['test_name'] = replace_dict['test_name'].replace("/", "_")
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
