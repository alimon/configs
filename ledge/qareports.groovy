if (manager.build.result == hudson.model.Result.SUCCESS) {
  def desc = manager.build.getDescription()
  if (desc == null) {
    desc = ""
  }

  pattern = ~"https://qa-reports.linaro.org/testjob/[0-9]+"
  manager.build.logFile.eachLine { line ->
    matcher = pattern.matcher(line)
    if (matcher.matches()) {
      def id = matcher.group(1)
      desc += "&nbsp;LAVA: <a href='https://qa-reports.linaro.org/testjob/${id}'>https://qa-reports.linaro.org/testjob/${id}</a><br/>"
    }
  }
  manager.build.setDescription(desc)
}
