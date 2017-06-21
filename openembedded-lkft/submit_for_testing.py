import argparse
import os
import requests
import sys
from string import Template

try:
    from urllib.parse import urlsplit
except ImportError:
    from urlparse import urlsplit


# Templates base path
template_base_path = 'configs/openembedded-lkft/lava-job-definitions'
# Snapshots base URL
snapshots_url = 'https://snapshots.linaro.org/openembedded/lkft'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--device-type",
                        help="Device type in LAVA",
                        dest="device_type",
                        required=True)
    parser.add_argument("--env-prefix",
                        help="Prefix for the environment name",
                        dest="env_prefix",
                        default="")
    parser.add_argument("--build-number",
                        help="Build number",
                        dest="build_number",
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
    parser.add_argument("--git-commit",
                        help="git commit ID",
                        dest="git_commit",
                        required=True)
    parser.add_argument("--template-path",
                        help="Path to LAVA job templates",
                        dest="template_path",
                        default=template_base_path)
    parser.add_argument("--template-names",
                        help="list of the templates to submit for testing",
                        dest="template_names",
                        nargs="+",
                        default=["template.yaml"])
    parser.add_argument("--quiet",
                        help="Only output the final qa-reports URL",
                        action='store_true',
                        dest="quiet")

    args, _ = parser.parse_known_args()

    if args.qa_token is None:
        print "QA_REPORTS_TOKEN is missing"
        sys.exit(1)

    qa_server_base = args.qa_server
    if not (qa_server_base.startswith("http://") or qa_server_base.startswith("https://")):
        qa_server_base = "https://" + qa_server_base
    qa_server_team = args.qa_server_team
    qa_server_project = args.qa_server_project
    qa_server_build = args.git_commit
    qa_server_env = args.env_prefix + args.device_type
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

    headers = {
        "Auth-Token": args.qa_token
    }
    for test in args.template_names:
        template_file_name = "%s/%s/%s" % (args.template_path, args.device_type, test)
        test_template = None
        if os.path.exists(template_file_name):
            test_template_file = open(template_file_name, "r")
            test_template = test_template_file.read()
            test_template_file.close()
        else:
            sys.exit(1)

        template = Template(test_template)
        print("using template: %s" % template_file_name)
        lava_job = template.substitute(os.environ)
        if not args.quiet:
            print(lava_job)
        try:
            data = {
                "definition": lava_job,
                "backend": urlsplit(lava_url_base).netloc  # qa-reports backends are named as lava instances
            }
            print("Submit to: %s" % qa_server_api)
            results = requests.post(qa_server_api, data=data, headers=headers)
            if results.status_code < 300:
                print("%s/testjob/%s" % (qa_server_base, results.text))
            else:
                print(results.status_code)
                print(results.text)
        except requests.exceptions.RequestException as err:
            print("QA Reports submission failed")
            if not args.quiet:
                print("offending job definition:")
                print(lava_job)


if __name__ == "__main__":
    main()
