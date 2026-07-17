# Scenario Notes

## Wrong Jenkins Agent Label

- Problem statement: the job requests `label 'linux'` but the configured label does not exist.
- Symptoms: build remains queued and Jenkins reports no matching agent.
- Logs to inspect: build queue, node configuration, controller logs.
- Commands to run: inspect Jenkins nodes and labels in the UI.
- Root cause: label mismatch.
- Corrective action: align job label and node label.
- Prevention: standardize labels in docs and templates.

## Agent Offline

- Problem statement: the agent container exists but is not connected.
- Symptoms: queued jobs and agent shown offline.
- Logs to inspect: controller logs and agent container logs.
- Commands to run: `docker compose logs agent`.
- Root cause: agent secret retrieval or network startup timing issue.
- Corrective action: restart agent after Jenkins is healthy.
- Prevention: health checks and startup verification scripts.

## Missing Credential ID

- Problem statement: pipeline references a credential ID that Jenkins does not have.
- Symptoms: `CredentialsUnavailableException`.
- Logs to inspect: build console output.
- Corrective action: create or fix the credential ID.
- Prevention: document credential IDs explicitly.
