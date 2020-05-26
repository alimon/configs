if (manager.build.result == hudson.model.Result.SUCCESS) {
  def repo = manager.envVars["KERNEL_REPO_URL"]
  def branch = manager.envVars["KERNEL_BRANCH"]
  def revision = manager.envVars["KERNEL_REVISION"]
  def configs = manager.envVars["KERNEL_CONFIGS_arm64"]

  def desc = "&nbsp;<h2>Trigger settings</h2><br />"
  desc += "&nbsp;<b>Repository:</b> ${repo}<br />"
  desc += "&nbsp;<b>Branch:</b> ${branch}<br />"
  desc += "&nbsp;<b>Revision:</b> ${revision}<br />"
  desc += "&nbsp;<b>Configs:</b> ${configs}<br />"

  manager.build.setDescription(desc)
}
