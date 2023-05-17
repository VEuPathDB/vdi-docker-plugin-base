FROM veupathdb/vdi-plugin-handler-server:1.0.6

ARG INSTALL_GIT_COMMIT_SHA=05197ebc4eb2046cc16e632b0b5852f21727a209
ARG CBIL_GIT_COMMIT_SHA=41e17a8c7c61a6ca55fd28bd0f4883c74dcb625c
ARG GUS_GIT_COMMIT_SHA=b11d5a179c5d48af134929c94b68bb908ab53bd6
ARG APICOMMONDATA_GIT_COMMIT_SHA=710c87e7527be170faeeba417f3165963bf4e139
ARG CLINEPIDATA_GIT_COMMIT_SHA=5238bc44754b7db7c1ce82da57e66264e53b3755

RUN apt-get update \
    && apt-get -y install ant git unzip python3 libaio1 libjson-perl \
                  libmodule-install-rdf-perl libxml-parser-perl \
                  libdate-manip-perl libtext-csv-perl \
                  libstatistics-descriptive-perl libtree-dagnode-perl \
                  libxml-simple-perl \
    && ln -s /usr/bin/python3 /usr/bin/python

WORKDIR /gusApp
WORKDIR /gusApp/gus_home
WORKDIR /gusApp/project_home

ENV GUS_HOME=/gusApp/gus_home
ENV PROJECT_HOME=/gusApp/project_home
ENV PATH=$PROJECT_HOME/install/bin:$PATH
ENV PATH=$GUS_HOME/bin:$PATH
ENV PATH=/opt/veupathdb/bin:$PATH

RUN git clone https://github.com/VEuPathDB/install.git \
    && cd install \
    && git checkout ${INSTALL_GIT_COMMIT_SHA}


RUN mkdir -p $GUS_HOME/config && cp $PROJECT_HOME/install/gus.config.sample $GUS_HOME/config/gus.config


RUN git clone https://github.com/VEuPathDB/CBIL.git \
    && cd CBIL \
    && git checkout ${CBIL_GIT_COMMIT_SHA} \
    && bld CBIL

RUN git clone https://github.com/VEuPathDB/GusAppFramework.git \
    && mv GusAppFramework GUS \
    && cd GUS \
    && git checkout ${GUS_GIT_COMMIT_SHA} \
    && bld GUS/PluginMgr \
    && bld GUS/Supported

RUN git clone https://github.com/VEuPathDB/ApiCommonData.git \
    && cd ApiCommonData \
    && git checkout ${APICOMMONDATA_GIT_COMMIT_SHA} \
    && mkdir -p $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin \
    && cp $PROJECT_HOME/ApiCommonData/Load/plugin/perl/*.pm $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/ \
    && cp -r $PROJECT_HOME/ApiCommonData/Load/lib/perl/* $GUS_HOME/lib/perl/ApiCommonData/Load/

RUN git clone https://github.com/VEuPathDB/ClinEpiData.git \
    && cd ClinEpiData \
    && git checkout ${CLINEPIDATA_GIT_COMMIT_SHA} \
    && bld ClinEpiData/Load


RUN perl -MCPAN -e 'install qq(Switch)' \
   && perl -MCPAN -e 'install qq(Config::Std)' \
   && perl -MCPAN -e 'install qq(XML::Simple)'


COPY ./bin/* /usr/local/bin/

# This Bit copies the Premade GUS Perl Objects
COPY ./res/model.tar.gz $GUS_HOME/lib/perl/GUS/
WORKDIR $GUS_HOME/lib/perl/GUS

RUN tar -xvzf model.tar.gz

WORKDIR /opt/oracle

RUN export INSTANTCLIENT_VER=linux.x64-21.6.0.0.0dbru \
    && wget https://download.oracle.com/otn_software/linux/instantclient/216000/instantclient-basic-$INSTANTCLIENT_VER.zip \
    && wget https://download.oracle.com/otn_software/linux/instantclient/216000/instantclient-tools-$INSTANTCLIENT_VER.zip \
    && wget https://download.oracle.com/otn_software/linux/instantclient/216000/instantclient-sdk-$INSTANTCLIENT_VER.zip \
    && unzip instantclient-basic-$INSTANTCLIENT_VER.zip \
    && unzip instantclient-tools-$INSTANTCLIENT_VER.zip \
    && unzip instantclient-sdk-$INSTANTCLIENT_VER.zip


# Need to change this if we get new version of the instantclient
ENV ORACLE_HOME=/opt/oracle/instantclient_21_6
ENV LD_LIBRARY_PATH=$ORACLE_HOME
ENV PATH=/opt/oracle/instantclient_21_6:$PATH

WORKDIR /tmp
RUN export DBI_VER=1.643 \
    && wget http://www.cpan.org/modules/by-module/DBI/DBI-$DBI_VER.tar.gz \
    && tar xvfz DBI-$DBI_VER.tar.gz \
    && cd DBI-$DBI_VER \
    && perl Makefile.PL \
    && make \
    && make install

RUN export ORACLE_DBD_VER=1.83 \
    && wget http://www.cpan.org/modules/by-module/DBD/DBD-Oracle-$ORACLE_DBD_VER.tar.gz \
    && tar xvfz DBD-Oracle-$ORACLE_DBD_VER.tar.gz \
    && cd DBD-Oracle-$ORACLE_DBD_VER \
    && perl Makefile.PL \
    && make \
    && make install

WORKDIR /
