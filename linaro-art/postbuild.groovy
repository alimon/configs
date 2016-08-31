import java.util.regex.Pattern

def MAX_TEST_FAILURES_DISPLAY = 5

def testFailedPattern = Pattern.compile("FAILING TESTS")
def errorSectionPattern = Pattern.compile("ERROR: Section: (.*) FAILED.*")
def testPattern = Pattern.compile(".*debuggable-(.*)")

def makeErrorPattern = ".*" + Pattern.quote("make: *** [") + "(.*)" + Pattern.quote("]") + ".*"
def failedCommandPattern = "ERROR: Failed command: (.*)"

def currentLineIsFailedTest = false
def testsFailed = false

def errorList = []
def testFailedList = []

manager.build.logFile.eachLine { line ->
  if (currentLineIsFailedTest) {
    matcher = testPattern.matcher(line)
    if (matcher?.matches()) {
      testFailedList << matcher.group(1)
    } else {
      currentLineIsFailedTest = false
    }
  }

  matcher = errorSectionPattern.matcher(line)
  if (matcher?.matches()) {
    errorList << matcher.group(1)
  }

  matcher = testFailedPattern.matcher(line)
  if (matcher?.matches()) {
    currentLineIsFailedTest = true
    testsFailed = true
  }
}

if (manager.logContains(".*Unable to determine architecture.*")) {
  manager.addWarningBadge("Unable to determine architecture bug was triggered.")
}

errorList.each {
  manager.addShortText(it, "white", "red", "1px", "grey")
}

if (testFailedList.size() <= MAX_TEST_FAILURES_DISPLAY) {
  testFailedList.each {
    manager.addShortText(it)
  }
} else {
  manager.addShortText("More than " + MAX_TEST_FAILURES_DISPLAY + " test failures")
}

if (!testsFailed) {
  def matcher = manager.getLogMatcher(makeErrorPattern)
  if ( matcher?.matches()) {
    manager.addShortText(matcher.group(1), "black", "silver", "1px", "grey")
  }
  matcher = manager.getLogMatcher(failedCommandPattern)
  if (matcher?.matches()) {
    manager.addShortText(matcher.group(1), "black", "orange", "1px", "red")
  }
}
