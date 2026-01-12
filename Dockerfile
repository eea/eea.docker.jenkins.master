FROM jenkins/jenkins:2.545

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt

RUN jenkins-plugin-cli --plugin-file=/usr/share/jenkins/ref/plugins.txt
ENV HOME $JENKINS_HOME

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends graphviz nodejs \
 && rm -rf /var/lib/apt/lists/* 

RUN mkdir -p /root/.ssh \
 && ssh-keyscan github.com >> /root/.ssh/known_hosts
 
USER ${user}

RUN mkdir -p ~/.ssh \
 && ssh-keyscan github.com >> ~/.ssh/known_hosts
