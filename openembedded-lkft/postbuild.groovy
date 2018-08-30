if (manager.build.result == hudson.model.Result.SUCCESS) {
  def qa_server = manager.envVars["QA_SERVER"]
  def desc = manager.build.getDescription()
  if (desc == null) {
    desc = ""
  }
  pattern = ~"(${qa_server}/testjob/(\\d+))(.*)"
  manager.build.logFile.eachLine { line ->
    matcher = pattern.matcher(line)
    if(matcher.matches()) {
      def url = matcher.group(1)
      def testjob_id = matcher.group(2)
      def job_name = matcher.group(3)
      desc += "&nbsp;<a href='${url}'>LAVA job (QA ${testjob_id})${job_name}</a><br/>"
    }
  }
  manager.build.setDescription(desc)
}
