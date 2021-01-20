import hudson.model.*

// Add a LAVA job link to the description
def matcher = manager.getLogMatcher(".*LAVA Job Id.*")
if (matcher?.matches()) {
    def lavaJobId = matcher.group(0).split(",")[0].substring(13)
    if (!lavaJobId.isInteger()) {
        lavaSubJobs = matcher.group(0).substring(14).split("]")[0].replaceAll("'", "").split(",")
        lavaJobId = lavaSubJobs[0]
    }
    def lavaServer = matcher.group(0).tokenize("/")[1]
    def lavaJobUrl = "https://${lavaServer}/scheduler/job/${lavaJobId}"
    def lavaDescription = "&nbsp;LAVA Job Id: <a href='${lavaJobUrl}'>${lavaJobId}</a>"

    def cause = manager.build.getAction(hudson.model.CauseAction.class).getCauses()
    def upstreamBuild = cause[0].upstreamBuild
    def upstreamProject = cause[0].upstreamProject
    def jobName = upstreamProject
    def jobConfiguration = upstreamProject
    def jobUrl = manager.hudson.getRootUrl() + "job/${upstreamProject}/${upstreamBuild}"
    def jobDescription = "<br>&nbsp;Build <a href='${jobUrl}'>${upstreamProject} #${upstreamBuild}</a>"

    manager.build.setDescription(lavaDescription + jobDescription)

    // Multi-configuration project
    if (upstreamProject.contains("/")) {
        jobName = upstreamProject.split("/")[0]
        jobConfiguration = upstreamProject.split("/")[1]
    }

    def jobs = hudson.model.Hudson.instance.getItem(jobName).getAllJobs()

    for (job in jobs) {
        if (job.name == jobConfiguration) {
            if (job.getLastBuild().getDescription() != null) {
                lavaDescription += "<br>" + job.getLastBuild().getDescription()
            }
            job.getLastBuild().setDescription(lavaDescription)
        }
    }

    // Add parameters
    def action = manager.build.getAction(hudson.model.ParametersAction.class)
    def parameters = [
            new StringParameterValue("LAVA_SERVER", "${lavaServer}/RPC2/"),
            new StringParameterValue("LAVA_JOB_ID", "${lavaJobId}"),
            new StringParameterValue("BUILD_JOB", "${jobUrl}")
    ]
    updatedAction = action.createUpdated(parameters)
    manager.build.replaceAction(updatedAction)

    // Update the pool of jobs to monitor
    job = hudson.model.Hudson.instance.getItem("check-lava-status")
    property = job.getProperty(hudson.model.ParametersDefinitionProperty.class)
    parameter = property.getParameterDefinition("LAVA_JOB_ID_POOL")
    lavaJobIdPool = parameter.getDefaultValue()
    lavaJobIdPool += " ${manager.build.number}"
    parameter.setDefaultValue(lavaJobIdPool)
    job.save()
}

