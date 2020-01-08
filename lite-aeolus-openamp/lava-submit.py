import os
import sys
import xmlrpc.client


# Actually submit job to LAVA
SUBMIT = 1

ENV = os.environ

with open(sys.argv[1]) as f:
    jobdef = f.read()

if SUBMIT:
    username = ENV["LAVA_USER"]
    token = ENV["LAVA_TOKEN"]
    uri = ENV["LAVA_SERVER"]
    if not uri.endswith("/"):
        uri += "/"

    print("https://%s:%s@%s" % (username, token, uri))
    server = xmlrpc.client.ServerProxy("https://%s:%s@%s" % (username, token, uri))

    job_id = server.scheduler.submit_job(jobdef)
    print("LAVA: https://%s../scheduler/job/%s" % (uri, job_id))
