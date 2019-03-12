if (manager.build.result == hudson.model.Result.SUCCESS) {
  def repo = manager.envVars["KERNEL_REPO_URL"]
  def branch = manager.envVars["KERNEL_BRANCH"]
  def revision = manager.envVars["KERNEL_REVISION"]
  def configs = manager.envVars["KERNEL_CONFIGS"]
  def arch = manager.envVars["ARCH"]

  def desc = "&nbsp;Trigger settings:<br />"
  desc += "&nbsp;Repository: ${repo}<br />"
  desc += "&nbsp;Branch: ${branch}<br />"
  desc += "&nbsp;Revision: ${revision}<br />"
  desc += "&nbsp;Configs: ${configs}<br />"
  desc += "&nbsp;Arch: ${arch}<br />"

  manager.build.setDescription(desc)
}
