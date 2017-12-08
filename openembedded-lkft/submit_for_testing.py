import argparse
import os
import requests
import sys
import StringIO
from copy import deepcopy
from string import Template
from jinja2 import Environment, FileSystemLoader, StrictUndefined
from ruamel.yaml import YAML


try:
    from urllib.parse import urlsplit
except ImportError:
    from urlparse import urlsplit


# Templates base path
template_base_path = 'configs/openembedded-lkft/lava-job-definitions'
testplan_base_path = 'configs/openembedded-lkft/lava-job-definitions/'
testplan_device_path = 'devices/'
# Snapshots base URL
snapshots_url = 'https://snapshots.linaro.org/openembedded/lkft'

def parse_template(yaml_string):
    '''
        Round trip lava_job through ruamel to test parsing and
        improve formatting. Comments are preserved.

        In: yaml-formatted string
        Out: validated yaml-formatted string
    '''
    yaml = YAML()
    # ruamel does not provide a mechanism to dump to string, so use StringIO
    # to catch it
    output = StringIO.StringIO()
    yaml.dump(yaml.load(yaml_string), output)
    return output.getvalue()

def _load_template(template_name, template_path, device_type):
    template = ''
    template_file_name = ''

    if template_name:
        template_file_name = "%s/%s/%s" % (template_path,
                                           device_type,
                                           template_name)
        if os.path.exists(template_file_name):
            with open(template_file_name, 'r') as f:
                template = f.read()
        else:
            print('template (%s) was specified but not exists' %
                  template_file_name)
            sys.exit(1)

    return template, template_file_name


def _submit_to_squad(lava_job, lava_url_base, qa_server_api, qa_server_base, qa_token, quiet):
    headers = {
        "Auth-Token": qa_token
    }

    try:
        data = {
            "definition": lava_job,
            "backend": urlsplit(lava_url_base).netloc  # qa-reports backends are named as lava instances
        }
        print("Submit to: %s" % qa_server_api)
        results = requests.post(qa_server_api, data=data, headers=headers,
                                timeout=31)
        if results.status_code < 300:
            print("%s/testjob/%s" % (qa_server_base, results.text))
        else:
            print(results.status_code)
            print(results.text)
    except requests.exceptions.RequestException as err:
        print("QA Reports submission failed")
        if not quiet:
            print("offending job definition:")
            print(lava_job)


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
    parser.add_argument("--env-suffix",
                        help="Suffix for the environment name",
                        dest="env_suffix",
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
    parser.add_argument("--testplan-path",
                        help="Path to Jinja2 LAVA job templates",
                        dest="testplan_path",
                        default=testplan_base_path)
    parser.add_argument("--testplan-device-path",
                        help="Relative path to Jinja2 device deployment fragments",
                        dest="testplan_device_path",
                        default=testplan_device_path)
    parser.add_argument("--template-base-pre",
                        help="base template used to construct templates, previous",
                        dest="template_base_pre")
    parser.add_argument("--template-base-post",
                        help="base template used to construct templates, posterior",
                        dest="template_base_post")
    parser.add_argument("--template-names",
                        help="list of the templates to submit for testing",
                        dest="template_names",
                        nargs="+",
                        default=[])
    parser.add_argument("--test-plan",
                        help="""list of the Jinja2 templates to submit for testing.
                        It is assumed that the templates produce valid LAVA job
                        definitions. All varaibles are substituted using Jinja2
                        engine. This includes environment variables.""",
                        dest="test_plan",
                        nargs="+",
                        default=[])
    parser.add_argument("--dry-run",
                        help="""Prepare and write templates to tmp/.
                        Don't submit to actual servers.""",
                        action='store_true',
                        dest="dryrun")
    parser.add_argument("--quiet",
                        help="Only output the final qa-reports URL",
                        action='store_true',
                        dest="quiet")

    args, _ = parser.parse_known_args()

    output_path = "tmp"
    if args.dryrun:
        if not os.path.exists(output_path):
            os.mkdir(output_path)
    if args.qa_token is None:
        print("QA_REPORTS_TOKEN is missing")
        sys.exit(1)

    qa_server_base = args.qa_server
    if not (qa_server_base.startswith("http://") or qa_server_base.startswith("https://")):
        qa_server_base = "https://" + qa_server_base
    qa_server_team = args.qa_server_team
    qa_server_project = args.qa_server_project
    qa_server_build = args.git_commit
    qa_server_env = args.env_prefix + args.device_type + args.env_suffix
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

    template_base_pre, _ = _load_template(args.template_base_pre,
                                          args.template_path,
                                          args.device_type)
    template_base_post, _ = _load_template(args.template_base_post,
                                           args.template_path,
                                           args.device_type)
    lava_jobs = []
    for test in args.template_names:
        test_template, template_file_name = _load_template(test,
                                                           args.template_path,
                                                           args.device_type)
        if template_base_pre:
            test_template = "%s\n%s" % (template_base_pre, test_template)
        if template_base_post:
            test_template = "%s\n%s" % (test_template, template_base_post)

        template = Template(test_template)
        print("using template: %s" % template_file_name)
        lava_job = template.substitute(os.environ)
        lava_job = parse_template(lava_job)
        lava_jobs.append(lava_job)

        if not args.quiet:
            print(lava_job)
        if args.dry_run:
            testpath = os.path.join(output_path, args.device_type, test)
            if not os.path.exists(os.path.dirname(testpath)):
                os.makedirs(os.path.dirname(testpath))
            with open(os.path.join(testpath), 'w') as f:
                f.write(lava_job)

    THIS_DIR = os.path.abspath(args.testplan_path)
    # prevent creating templates when variables are missing
    j2_env = Environment(loader=FileSystemLoader(THIS_DIR), undefined=StrictUndefined)
    context = deepcopy(os.environ)
    context.update({"device_type": os.path.join(args.testplan_device_path, args.device_type)})
    for test in args.test_plan:
        ''' Prepare lava jobs '''
        lava_job = j2_env.get_template(test).render(context)
        lava_job = parse_template(lava_job)
        lava_jobs.append(lava_job)

        if not args.quiet:
            print(lava_job)
        if args.dryrun:
            testpath = os.path.join(output_path, args.device_type, test)
            if not os.path.exists(os.path.dirname(testpath)):
                os.makedirs(os.path.dirname(testpath))
            with open(os.path.join(testpath), 'w') as f:
                f.write(lava_job)

    for lava_job in lava_jobs:
        ''' Submit lava jobs '''
        if not args.dryrun:
            _submit_to_squad(lava_job,
                lava_url_base,
                qa_server_api,
                qa_server_base,
                args.qa_token,
                args.quiet)


if __name__ == "__main__":
    main()
