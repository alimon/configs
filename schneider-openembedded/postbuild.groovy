if (manager.build.result == hudson.model.Result.SUCCESS) {
  def desc = manager.build.getDescription()
  if (desc == null) {
    desc = ""
  }
  pattern = ~/CVE_NEW:\t([^\t]+\t[^\t]+)\t([^t]+)/
  def map = [:]
  manager.build.logFile.eachLine { line ->
    matcher = pattern.matcher(line)
    if(matcher.matches()) {
      def pkg = matcher.group(1)
      def cve = matcher.group(2)
      map["${pkg}"] = "${cve}"
      //desc += "&nbsp;NEW CVE in ${pkg} <a href='https://nvd.nist.gov/vuln/detail/${cve}'>${cve}</a><br/>"
    }
  }
  //manager.build.setDescription(desc)
  if(map.size() > 0) {
      def summary = manager.createSummary("warning.gif")
      summary.appendText("New CVEs:<ul>", false)
      map.each {
          summary.appendText("<li><a href=\"https://nvd.nist.gov/vuln/detail/$it.value\">$it.value</a> in $it.pkg</li>", false)
      }
      summary.appendText("</ul>", false)
  }
}
