import os
import sys
from string import Template
import xmlrpclib

# Actually submit job to LAVA
SUBMIT = 1

ENV = os.environ
expect = sys.argv[1]

ENV["JOB_NAME_SHORT"] = ENV["JOB_NAME"].split("/", 1)[0]

with open("lava-job-definitions/%s/template.yaml" % ENV["DEVICE_TYPE"]) as f:
    tpl = f.read()


TEST_SPEC = """\
    monitors:
    - name: "boot_test"
      start: ""
      end: "%s"
      pattern: _unused_
""" % expect

tpl = Template(tpl)
jobdef = tpl.safe_substitute(ENV, TEST_SPEC=TEST_SPEC)

print(jobdef)

if SUBMIT:
    username = os.getenv("LAVA_USER")
    token = os.getenv("LAVA_TOKEN")
    uri = os.getenv("LAVA_SERVER")
    server = xmlrpclib.ServerProxy("https://%s:%s@%s" % (username, token, uri))

    job_id = server.scheduler.submit_job(jobdef)
    print("https://%s../scheduler/job/%s" % (uri, job_id))
