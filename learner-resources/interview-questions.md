# Jenkins Interview Questions

1. What problem does Jenkins solve?
Answer: It automates build, test, and deployment workflows so teams get fast and consistent feedback.

2. What is the difference between a controller and an agent?
Answer: The controller schedules and stores configuration. The agent executes the build steps.

3. Why should builds usually not run on the controller?
Answer: It reduces blast radius, resource contention, and security risk.

4. What is a Jenkinsfile?
Answer: A pipeline definition stored as code in the repository.

5. What is the difference between freestyle jobs and pipelines?
Answer: Freestyle jobs are UI-configured. Pipelines are code-defined and version-controlled.

6. What does `numExecutors: 0` mean on a controller?
Answer: The controller will not run build workloads.

7. Why use credential IDs?
Answer: They let pipelines reference secrets securely without hardcoding values.

8. What is a webhook?
Answer: An HTTP callback that triggers Jenkins when repository events happen.

9. What is JCasC?
Answer: Jenkins Configuration as Code, which lets you define Jenkins configuration in YAML.

10. Why is the Docker socket risky?
Answer: Access to the Docker daemon can often lead to host-level control.

11. Why use Session Manager in AWS?
Answer: It avoids public SSH exposure and centralizes access control through IAM.

12. What belongs in `JENKINS_HOME`?
Answer: Jobs, plugins, credentials metadata, configuration, logs, and build history.

13. What is a build agent label?
Answer: A selector Jenkins uses to match jobs to capable agents.

14. Why pin versions in learning repositories?
Answer: Reproducibility and easier troubleshooting.

15. What is a smoke test?
Answer: A small validation that proves the built application starts and basic functionality works.

16. Why keep cleanup instructions in labs?
Answer: Learners need to remove cost, state drift, and port conflicts safely.

17. What happens if an agent goes offline?
Answer: Jobs that need that label stay queued or fail if no matching agent is available.

18. What is build retention?
Answer: Rules that remove old builds to control disk usage.

19. Why archive test reports?
Answer: Jenkins can show test history and failed test details across builds.

20. What is concurrency control in Jenkins?
Answer: Rules such as `disableConcurrentBuilds()` that prevent overlapping builds.

21. Why separate runtime and development Python dependencies?
Answer: It keeps production images smaller and reduces unnecessary attack surface.

22. Why avoid storing AWS keys in Jenkins on EC2?
Answer: IAM roles already provide temporary credentials more safely.

23. What should you inspect when Jenkins fails to start?
Answer: service status, `journalctl`, Java version, port conflicts, and disk usage.

24. Why keep diagrams in source form?
Answer: They are easier to review, update, and validate in version control.

25. When is a single-instance Jenkins acceptable?
Answer: Learning, demos, and small internal setups where high availability is not required.
