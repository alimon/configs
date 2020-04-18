if (manager.build.result == hudson.model.Result.SUCCESS) {
  pattern = ~/^(\S+)\t(CVE-\S+)\t([^\t]+)\t([^\t]+)/
  def cve = [
	NEW:     [],
	CHANGED: [],
	FIXED:   [],
  ]
  manager.build.logFile.eachLine { line ->
    matcher = pattern.matcher(line)
    if(matcher.matches()) {
      def type = matcher.group(1)
      def num = matcher.group(2)
      def pkg = matcher.group(3)
      def url = matcher.group(4)
      cve[type].add("<a href=\"${url}\">${num}</a> ${pkg}")
    }
  }
  def summary = manager.createSummary("warning.gif")
  cve.each {
    if(it.value.size() > 0) {
      summary.appendText("$it.key CVEs:<ul>", false)
      it.value.each {
          summary.appendText("<li>$it</li>", false)
      }
      summary.appendText("</ul>", false)
    }
  }
}
