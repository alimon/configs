if (manager.build.result == hudson.model.Result.SUCCESS) {
  def pub_dest = manager.build.buildVariables.get('PUB_DEST')

  def url = "http://builds.96boards.org/${pub_dest}/"
  def desc = "&nbsp;<a href='${url}'>Build location<t/a><br />"

  manager.build.setDescription(desc)
}
