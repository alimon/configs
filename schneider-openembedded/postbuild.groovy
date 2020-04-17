if (manager.build.result == hudson.model.Result.SUCCESS) {
  def desc = manager.build.getDescription()
  if (desc == null) {
    desc = ""
  }
  pattern = ~/CVE_NEW\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/
  def map = [:]
  manager.build.logFile.eachLine { line ->
    matcher = pattern.matcher(line)
    if(matcher.matches()) {
      def pkgver = matcher.group(1)
      def cssv2 = matcher.group(2)
      def cssv3 = matcher.group(3)
      def cve = matcher.group(4)
      map[pkgver] = "<a href='https://nvd.nist.gov/vuln/detail/${cve}'>${cve}</a> score ${cssv3}"
    }
  }
  if(map.size() > 0) {
      def summary = manager.createSummary("warning.gif")
      summary.appendText("New CVEs:<ul>", false)
      map.each {
          summary.appendText("<li>$it.value in $it.key</li>", false)
      }
      summary.appendText("</ul>", false)
  }
}
