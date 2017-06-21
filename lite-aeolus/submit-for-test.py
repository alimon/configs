import os
import sys
from string import Template


ENV = os.environ
expect = sys.argv[1]

ENV["DEVICE_TYPE"] = "frdm-k64f"

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
