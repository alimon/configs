import os
import sys
from string import Template


ENV = os.environ
expect = sys.argv[1]

ENV["JOB_NAME_SHORT"] = ENV["JOB_NAME"].split("/", 1)[0]

tpl_suffix = ENV.get("TEST_TYPE", "")
if tpl_suffix:
    tpl_suffix = "-" + tpl_suffix

with open("lava-job-definitions/%s/template%s.yaml" % (ENV["DEVICE_TYPE"], tpl_suffix)) as f:
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
