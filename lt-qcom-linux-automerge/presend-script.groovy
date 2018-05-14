automerge_config = sprintf(build.envVars["AUTOMERGE_CONFIG"])
automerge_branch_failed = sprintf(build.envVars["AUTOMERGE_BRANCH_FAILED"])

msg.setContent(msg.getContent().replace("{{AUTOMERGE_CONFIG}}", automerge_config), 'text/plain')
msg.setContent(msg.getContent().replace("{{AUTOMERGE_BRANCH_FAILED}}", automerge_branch_failed), 'text/plain')
