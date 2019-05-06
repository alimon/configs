/*
    This lovely groovy script is used to send the jenkins build result to
    qa-reports.linaro.org (SQUAD).

    It requires the following variables to be available in the environment:
    DEVICE_TYPE: This becomes the environment in qa-reports
    QA_SERVER: URL for qa-reports (squad) host.
    QA_REPORTS_TOKEN: Auth token for qa-reports (squad) host.
    QA_SERVER_PROJECT: qa-reports project name
    KERNEL_DESCRIBE: This becomes build version in qa-reports (squad).

    Optional variables:
    QA_SERVER_TEAM: This becomes the group in qa-reports. It defaults to 'lkft'
    KERNEL_REPO: metadata - git repo url. Defaults to 'unknown'.
    KERNEL_COMMIT: metadata - git commit sha. Defaults to 'unknown'.
    KERNEL_BRANCH: metadata - git branch. Defaults to 'unknown'.
    MAKE_KERNELVERSION: metadata - result of 'make kernelversion'. Defaults to 'unknown'.

    If the jenkins job is successful, a 'build/build_process' test result will
    be set to 'pass' in qa-reports, otherwise it will get a 'fail' result.

    To test changes to this script:
    - Set up a local jenkins container
    - Create a job
    - Add QA_REPORTS_TOKEN 'secret text' under 'Use secret text(s) or file(s)
    - Untick 'Inject nevironment variables to the build process'
      - Paste the following (for example) into the 'Properties Content':
          DEVICE_TYPE=x15
          QA_SERVER=https://staging-qa-reports.linaro.org
          QA_SERVER_PROJECT=linux-mainline-oe
          KERNEL_DESCRIBE=v4.20.1
    - Enable Groovy Postbuild and paste this script in

    A build error log is extracted from the jenkins log using a regular
    expression, and included in the test result.

*/
def device_type = manager.envVars["DEVICE_TYPE"]
def qa_server_team = 'lkft'
if (manager.envVars.containsKey('QA_SERVER_TEAM')) {
    qa_server_team = manager.envVars["QA_SERVER_TEAM"]
}
def base_url = manager.envVars['QA_SERVER']
def auth_token = manager.envVars["QA_REPORTS_TOKEN"]
def build_process = "fail"
def log_error_pattern = ~'^ERROR: .*$'
if (manager.build.result == hudson.model.Result.SUCCESS) {
    build_process = "pass"
}
def url_path = '/api/submit/' +
               qa_server_team +
               '/' +
               manager.envVars["QA_SERVER_PROJECT"] +
               '/' +
               manager.envVars["KERNEL_DESCRIBE"] +
               '/' +
               device_type
def url_path_sanity = '/api/submit/' +
               qa_server_team +
               '/' +
               manager.envVars["QA_SERVER_PROJECT"] + '-sanity' +
               '/' +
               manager.envVars["KERNEL_DESCRIBE"] +
               '/' +
               device_type

def error_log = ""
manager.build.logFile.eachLine { line ->
    matcher = log_error_pattern.matcher(line)
    if (matcher.matches()) {
        error_log += line+"\n"
    }
}

@Grab(group='org.codehaus.groovy.modules.http-builder', module='http-builder', version='0.7' )
import groovyx.net.http.HTTPBuilder
import static groovyx.net.http.ContentType.URLENC

def http = new HTTPBuilder(base_url)
def postBody = [
    tests: '{"build/build_process": "'+ build_process +'"}',
    log: error_log,
    metadata:
        // This is fussy, but I thought it was easier than figuring out how to
        // add JsonOutput
        """{
            "job_id": "${device_type}-${manager.build.number}",
            "git branch": "${manager.envVars.get("KERNEL_BRANCH", "unknown")}",
            "git repo": "${manager.envVars.get("KERNEL_REPO", "unknown")}",
            "git commit": "${manager.envVars.get("KERNEL_COMMIT", "unknown")}",
            "git describe": "${manager.envVars.get("KERNEL_DESCRIBE", "unknown")}",
            "make_kernelversion": "${manager.envVars.get("MAKE_KERNELVERSION", "unknown")}"
        }"""
]
http.headers['Auth-Token'] = auth_token

http.post(path: url_path,
          body: postBody,
          requestContentType: URLENC ) { resp ->
  println "POST Success: ${resp.statusLine}"
  assert resp.statusLine.statusCode == 201
}
http.post(path: url_path_sanity,
          body: postBody,
          requestContentType: URLENC ) { resp ->
  println "POST Success: ${resp.statusLine}"
  assert resp.statusLine.statusCode == 201
}
