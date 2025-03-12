FROM foxcapades/ubuntu-corretto:24.10-jdk21

ENV LANG=en_US.UTF-8 \
  JVM_MEM_ARGS="-Xms16m -Xmx64m" \
  JVM_ARGS="" \
  TZ="America/New_York"

RUN apt-get update \
  && apt-get install -y locales \
  && sed -i -e "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen \
  && dpkg-reconfigure --frontend=noninteractive locales \
  && update-locale LANG=en_US.UTF-8 \
  && apt-get install -y tzdata curl wget \
  && cp /usr/share/zoneinfo/America/New_York /etc/localtime \
  && echo ${TZ} > /etc/timezone \
  && apt-get clean

ENV PATH=/opt/veupathdb/bin:$PATH

COPY lib/ /opt/veupathdb/lib/

ARG PLUGIN_SERVER_VERSION=v8.1.2
RUN set -o pipefail \
    && curl "https://github.com/VEuPathDB/vdi-plugin-handler-server/releases/download/${PLUGIN_SERVER_VERSION}/docker-download.sh" -Lf --no-progress-meter | bash

CMD /startup.sh
