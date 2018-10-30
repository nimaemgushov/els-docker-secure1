FROM centos:7.5.1804

USER root
RUN mkdir -p /deployments

# JAVA_APP_DIR is used by run-java.sh for finding the binaries
ENV JAVA_APP_DIR=/deployments \
  JAVA_MAJOR_VERSION=8
  # Tomcat and Java Vars
ENV JDK_MAJOR_VERSION=8u74 \
    JDK_VERSION=1.8.0_74 \
    TOMCAT_MAJOR_VERSION=8 \
    TOMCAT_VERSION=8.0.38 \
    JAVA_HOME=/opt/java \
    CATALINA_HOME=/opt/tomcat \
    PATH=$PATH:$JAVA_HOME/bin:${CATALINA_HOME}/bin:${CATALINA_HOME}/scripts \
    JAVA_OPTS="-Xms512m -Xmx2048m"


# /dev/urandom is used as random source, which is prefectly safe # according to http://www.2uo.de/myths-about-urandom/
RUN yum -y update && yum clean all && yum -y install wget

RUN yum install -y \
       java-1.8.0-openjdk-1.8.0.181-3.b13.el7_5 \
       java-1.8.0-openjdk-devel-1.8.0.181-3.b13.el7_5 \
       && echo "securerandom.source=file:/dev/urandom" >> /usr/lib/jvm/java/jre/lib/security/java.security

ENV JAVA_HOME /etc/alternatives/jre

# Add run script as /deployments/run-java.sh and make it executable
COPY run-java.sh /deployments/
RUN chmod 755 /deployments/run-java.sh

# Download tomcat from mirror and install into /opt
wget -nv http://apache.mirror.gtcomm.net/tomcat/tomcat-${TOMCAT_MAJOR_VERSION}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz \
-O /opt/apache-tomcat-${TOMCAT_VERSION}.tar.gz && \
echo "Checking file integrity..." && \
sha1sum -c /opt/apache-tomcat-${TOMCAT_VERSION}.tar.gz.sha && \
tar xf /opt/apache-tomcat-${TOMCAT_VERSION}.tar.gz && \
rm  apache-tomcat-${TOMCAT_VERSION}.tar.gz && \
mv apache-tomcat-${TOMCAT_VERSION} ${CATALINA_HOME} && \
chmod +x ${CATALINA_HOME}/bin/*sh

rm -rf ${CATALINA_HOME}/webapps/* && \
    rm -rf ${CATALINA_HOME}/server/webapps/* && \
    ###
    # Obscuring server info
    ###
    cd ${CATALINA_HOME}/lib && \
    mkdir -p org/apache/catalina/util/ && \
    unzip -j catalina.jar org/apache/catalina/util/ServerInfo.properties \
        -d org/apache/catalina/util/ && \
    sed -i 's/server.info=.*/server.info=Apache Tomcat/g' \
        org/apache/catalina/util/ServerInfo.properties && \
    zip -ur catalina.jar \
        org/apache/catalina/util/ServerInfo.properties && \
    rm -rf org && cd ${CATALINA_HOME} \
    sed -i 's/<Connector/<Connector server="Apache" secure="true"/g' \
        ${CATALINA_HOME}/conf/server.xml && \
    ###
    # Ugly, embarrassing, fragile solution to adding the CredentialHandler
    # element until we get XSLT or the equivalent figured out. True for other
    # XML manipulations herein.
    # https://github.com/Unidata/tomcat-docker/issues/27
    # https://stackoverflow.com/questions/32178822/tomcat-understanding-credentialhandler
    ##

    sed -i 's/resourceName="UserDatabase"\/>/resourceName="UserDatabase"><CredentialHandler className="org.apache.catalina.realm.MessageDigestCredentialHandler" algorithm="SHA" \/><\/Realm>/g' \
        ${CATALINA_HOME}/conf/server.xml && \

    ###
    # Setting restrictive umask container-wide
    ###
    echo "session optional pam_umask.so" >> /etc/pam.d/common-session && \
sed -i 's/UMASK.*022/UMASK           007/g' /etc/login.defs


USER jboss
CMD [ "/deployments/run-java.sh" ]
