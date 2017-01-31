// Issues that relate to all tests:
if (manager.logContains(".*Unexpected termination of the channel.*")) {
  manager.addShortText("Infrastructure problem", "black", "orange", "1px", "red")
}
