if (manager.build.result == hudson.model.Result.SUCCESS) {
  def desc = manager.build.getDescription()
  if (desc == null) {
    desc = ""
  }
  pattern = ~"LAVA: (.+)"
  manager.build.logFile.eachLine { line ->
    matcher = pattern.matcher(line)
    if (matcher.matches()) {
      def url = matcher.group(1)
      desc += "&nbsp;LAVA: <a href='${url}'>${url}</a><br/>"
    }
  }
  manager.build.setDescription(desc)
}
