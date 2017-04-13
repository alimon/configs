import argparse
import os
import sys
from string import Template

try:
    # try python3 first
    from xmlrpc import client as xmlrpclib
except ImportError:
    import xmlrpclib

try:
    from urllib.parse import urlsplit
except ImportError:
    from urlparse import urlsplit


class LAVA(object):
    def __init__(self, url, username, token):
        self.url = url
        self.username = username
        self.token = token
        self.__proxy__ = None

    @property
    def proxy(self):
        if self.__proxy__ is None:
            url = urlsplit(self.url)
            endpoint = '%s://%s:%s@%s%s' % (
                url.scheme,
                self.username,
                self.token,
                url.netloc,
                url.path
            )
            self.__proxy__ = xmlrpclib.ServerProxy(endpoint)
        return self.__proxy__


tests = [
    "drivers/spi/spi_basic_api/test_spi",
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
    "kernel/fp_sharing/test_arm",
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
    "bluetooth/test_bluetooth/test",
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
    parser.add_argument("--lava-user",
                        help="LAVA user",
                        dest="lava_user",
                        default=os.environ.get('LAVA_USER'))
    parser.add_argument("--lava-token",
                        help="LAVA token",
                        dest="lava_token",
                        default=os.environ.get('LAVA_TOKEN'))
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

    lava_url_base = "https://%s/" % urlsplit(args.lava_server).netloc
    lava_url = lava_url_base + "RPC2/"
    l = LAVA(lava_url, args.lava_user, args.lava_token)
    test_url_prefix = "%s/%s/%s/%s/%s/tests/" % (
        snapshots_url, args.branch_name, args.gcc_variant, args.board_name, args.build_number)

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
            results = l.proxy.scheduler.submit_job(lava_job)
            print("%s/scheduler/job/" % (lava_url_base, results))
        except xmlrpclib.ProtocolError as err:
            print("LAVA submission failed")
            print("offending job definition:")
            print(lava_job)
            print("Error code: %d" % err.errcode)
            print("Error message: %s" % err.errmsg)


if __name__ == "__main__":
    main()
