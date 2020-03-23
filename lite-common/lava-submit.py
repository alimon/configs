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

    server = xmlrpc.client.ServerProxy("https://%s:%s@%s" % (username, token, uri))

    job_id = server.scheduler.submit_job(jobdef)
    # Multinode job submission returns a list of per-node id's. We output
    # just the first id, as the rest of related jobs are reachable from
    # LAVA UI.
    if isinstance(job_id, list):
        job_id = job_id[0]
    print("LAVA: https://%s../scheduler/job/%s" % (uri, job_id))
