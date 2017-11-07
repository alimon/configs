import hudson.model.*

if (manager.build.result == hudson.model.Result.SUCCESS) {
  def qa_server = manager.build.buildVariables.get('QA_SERVER')
  def desc = manager.build.getDescription()
  if (desc == null) {
    desc = ""
  }
  pattern = ~"${qa_server}/testjob/(\\d+)"
  manager.build.logFile.eachLine { line ->
    matcher = pattern.matcher(line)
    if(matcher.matches()) {
      def url = matcher.group(0)
      def testjob_id = matcher.group(1)
      desc += "&nbsp;<a href='${url}'>QA Reports: ${testjob_id}</a><br/>"
    }
  }
  manager.build.setDescription(desc)
}

// Parse log file to find warnings and errors
def logFile = manager.build.logFile.text
def warnings = logFile =~ /(?ms)(^.*? warning: .*?$)/
def errors = logFile =~ /(?ms)(^.*? error: .*?$)/
def warningsCount = warnings.count
def errorsCount = errors.count

// Update parameters to include warnings and errors values
def action = manager.build.getAction(hudson.model.ParametersAction.class)
def parameters = [
  new StringParameterValue("WARNINGS", "${warningsCount}"),
  new StringParameterValue("ERRORS", "${errorsCount}")
]
updatedAction = action.createUpdated(parameters)
manager.build.replaceAction(updatedAction)
