# Glossary

## Jenkins Controller

Technical: the Jenkins service that stores configuration, schedules builds, and manages agents.

Simple: the Jenkins brain that assigns work.

Example: when a webhook arrives, the controller decides which job and agent should run next.

## Jenkins Agent

Technical: a machine or container that executes build steps on behalf of the controller.

Simple: the worker that does the actual job.

Example: a `linux` agent runs `pytest`, `docker build`, or `mvn test`.

## JENKINS_HOME

Technical: the main Jenkins data directory that stores jobs, plugins, credentials metadata, and build history.

Simple: the folder where Jenkins keeps its memory.

Example: losing `JENKINS_HOME` without backup means losing job configuration and history.

## Webhook

Technical: an HTTP callback sent by a source control system to notify Jenkins of an event such as a push.

Simple: an automatic message that says, "new code arrived."

Example: Gitea sends a webhook to Jenkins after a commit so the pipeline starts immediately.
