if (manager.build.result == hudson.model.Result.SUCCESS) {
  qa_server = manager.envVars["QA_SERVER"]
  qa_server_team = manager.envVars["QA_SERVER_TEAM"]
  if (qa_server_team == null) {
    qa_server_team = "lkft"
  }
  qa_server_project = manager.envVars["QA_SERVER_PROJECT"]
  kernel_describe = manager.envVars["KERNEL_DESCRIBE"]
  build_number = manager.envVars["BUILD_NUMBER"]
  qa_build = kernel_describe + "-b" + build_number
  test_suites = manager.envVars["TEST_SUITES"]

  if (test_suites != "")
  {
    def qa_desc = manager.build.getDescription()
    if (qa_desc == null) {
      qa_desc = ""
    }
    qa_desc += "&nbsp;<a href='${qa_server}/${qa_server_team}/${qa_server_project}/build/${qa_build}'>QA Reports</a><br/>"
    manager.build.setDescription(qa_desc)
  }
}
