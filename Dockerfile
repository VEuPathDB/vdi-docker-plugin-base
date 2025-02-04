FROM ubuntu:24.10

ARG GITHUB_TOKEN

ARG PLUGIN_SERVER_VERSION=v8.1.0-rc3

ARG JAVA_VERSION=21.0.6.7.1

ENV JAVA_HOME=/opt/java \
  LANG=en_US.UTF-8

RUN apt-get update \
  && apt-get install -y locales \
  && sed -i -e "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen \
  && dpkg-reconfigure --frontend=noninteractive locales \
  && update-locale LANG=en_US.UTF-8 \
  && apt-get install -y curl wget \
  && apt-get clean \
  \
  && mkdir -p ${JAVA_HOME} \
  && cd ${JAVA_HOME} \
  && curl -Lso java.tgz https://corretto.aws/downloads/resources/${JAVA_VERSION}/amazon-corretto-${JAVA_VERSION}-linux-x64.tar.gz \
  && tar -xf java.tgz \
  && rm java.tgz \
  && mv amazon-corretto-${JAVA_VERSION}-linux-x64/* .

ENV PATH=/opt/veupathdb/bin:$PATH

COPY lib/ /opt/veupathdb/lib/

RUN curl "https://github.com/VEuPathDB/vdi-plugin-handler-server/releases/download/${PLUGIN_SERVER_VERSION}/service.jar" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" -LsO \
  && curl "https://raw.githubusercontent.com/VEuPathDB/vdi-plugin-handler-server/refs/tags/${PLUGIN_SERVER_VERSION}/startup.sh" -LsO \
  && chmod +x startup.sh

CMD /startup.sh