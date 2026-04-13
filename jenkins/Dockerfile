FROM jenkins/jenkins:lts-jdk17

USER root

# Install Docker CLI inside Jenkins container
RUN apt-get update \
    && apt-get install -y --no-install-recommends docker.io ca-certificates curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# (Optional) allow the jenkins user to invoke docker when the socket is mounted.
# NOTE: On Docker Desktop the socket permissions can vary; running as root is simplest.
RUN usermod -aG docker jenkins || true

USER jenkins
