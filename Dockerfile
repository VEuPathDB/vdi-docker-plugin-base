FROM veupathdb/vdi-plugin-handler-server:2.0.3

RUN apt-get update \
    && apt-get -y install python3 \
    && apt-get clean \
    && ln -s /usr/bin/python3 /usr/bin/python

ENV PATH=/opt/veupathdb/bin:$PATH

COPY lib/ /opt/veupathdb/lib/
