if (manager.build.result == hudson.model.Result.SUCCESS) {
  def publish_server = manager.envVars["PUBLISH_SERVER"]
  def pub_dest = manager.envVars["PUB_DEST"]

  def desc = "&nbsp;<a href='${publish_server}${pub_dest}'>Build location<t/a><br />"

  manager.build.setDescription(desc)
}
