if (manager.getResult() == "SUCCESS") {
  def qa_server = manager.build.buildVariables.get('QA_SERVER')
  def desc = manager.build.getDescription()
  if (desc == null) {
    desc = ""
  }
  pattern = ~"${qa_server}/testjob/(\\d+)"
  manager.build.logFile.eachLine { line ->
    matcher = pattern.matcher(line)
    if(matcher.matches()) {
      def url = matcher.group(0)
      def testjob_id = matcher.group(1)
      desc += "&nbsp;<a href='${url}'>QA Reports: ${testjob_id}</a><br/>"
    }
  }
  manager.build.setDescription(desc)
}
