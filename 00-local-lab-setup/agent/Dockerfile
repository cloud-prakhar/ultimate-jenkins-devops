FROM jenkins/inbound-agent:jdk21

USER root

# Local lab image: we intentionally do not pin apt package versions here so the
# lab keeps working as the Debian base moves. Pin versions in production images.
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      curl \
      jq \
      git \
      docker.io \
      unzip \
      iputils-ping \
      procps \
      net-tools \
      dnsutils && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/local-agent-entrypoint.sh
RUN chmod +x /usr/local/bin/local-agent-entrypoint.sh

USER jenkins

ENTRYPOINT ["/usr/local/bin/local-agent-entrypoint.sh"]
