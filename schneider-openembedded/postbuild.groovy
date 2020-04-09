if (manager.build.result == hudson.model.Result.SUCCESS) {
  pattern = ~/CVE_NEW:\t([^\t]+\t[^\t]+)\t([^t]+)/
  def map = [:]
  manager.build.logFile.eachLine { line ->
      matcher = pattern.matcher(line)
      if(matcher.matches()) {
          def pkg = matcher.group(1)
          def cve = matcher.group(2)
          map[pkg] = cve
      }
  }
  if(map.size() > 0) {
      def summary = manager.createSummary("warning.gif")
      summary.appendText("New CVEs:<ul>", false)
      map.each {
          summary.appendText("<li><b>$it.pkg</b> - <a href=\"https://nvd.nist.gov/vuln/detail/CVE-2020-6096/$it.value\">$it.value</a></li>", false)
      }
      summary.appendText("</ul>", false)
  }
}
