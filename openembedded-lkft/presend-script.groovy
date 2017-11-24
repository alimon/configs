srcrev = build.envVars["SRCREV_kernel"].substring(0,12)
msg.setSubject(msg.getSubject().replace("{{SRCREV_kernel}}", srcrev))
