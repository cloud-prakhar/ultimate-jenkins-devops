FROM jenkins/jenkins:2.516.3-lts-jdk21

USER root

# Local lab image: we intentionally do not pin apt package versions here so the
# lab keeps working as the Debian base moves. Pin versions in production images.
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl \
      git \
      jq \
      docker.io \
      unzip \
      iputils-ping \
      procps \
      net-tools \
      dnsutils && \
    rm -rf /var/lib/apt/lists/*

USER jenkins

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/jenkins.yaml

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

COPY jenkins.yaml /var/jenkins_home/casc_configs/jenkins.yaml
