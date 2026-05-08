# Custom Jenkins image for the local learning lab.
#
# What this adds on top of the official image:
#   1. Docker CLI — so Jenkins can run `docker build` and `docker push`
#   2. Pre-installed plugins — no waiting for the setup wizard
#   3. JCasC configuration — Jenkins is fully configured on first boot
#
# ⚠️  LOCAL LAB ONLY: This image runs the Jenkins process as root
#     to avoid Docker socket permission issues on all platforms.
#     NEVER use root in production.

FROM jenkins/jenkins:lts-jdk21

# Switch to root to install system packages
USER root

# Install Docker CLI (not the daemon — we use the host daemon via the mounted socket)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        docker.io \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Switch back to the jenkins user for all subsequent layers
USER jenkins

# Skip the interactive setup wizard — JCasC handles all configuration
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

# Tell the JCasC plugin where to find its configuration file
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/jenkins.yaml

# Pre-install all plugins at build time so startup is fast
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli \
        --plugin-file /usr/share/jenkins/ref/plugins.txt \
        --verbose

# Seed the JCasC configuration into the image.
# At runtime, JCasC will substitute ${ENV_VAR} placeholders from the container environment.
COPY jenkins.yaml /var/jenkins_home/casc_configs/jenkins.yaml
