# Troubleshooting

## Wrong Agent Label

- Symptom: build remains queued.
- Fix: ensure the local lab agent is online and has label `linux`.

## Docker Permission Denied

- Symptom: Docker steps fail on the agent.
- Fix: verify the lab mounted `/var/run/docker.sock` and the agent container is running.

## Registry Push Fails

- Symptom: push to `localhost:5000` fails.
- Fix: verify the registry container is healthy and Docker trusts `localhost:5000` as an insecure registry.

## Test Reports Missing

- Symptom: build passes but Jenkins shows no JUnit results.
- Fix: confirm `test-results/junit.xml` exists and the `junit` step points to the correct path.
