FROM ubuntu:24.04

# Avoid interactive prompts during apt
ENV DEBIAN_FRONTEND=noninteractive

# Install all dependencies in one layer
RUN apt-get update && apt-get install -y \
    openjdk-11-jdk \
    openssh-server \
    openssh-client \
    wget vim curl net-tools \
    netcat-openbsd \
    pdsh \
    sudo \
    dos2unix \

    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
ENV ZOOKEEPER_HOME=/opt/zookeeper
ENV ZOOKEEPER_CONF_DIR=$ZOOKEEPER_HOME/conf
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin

# Copy tarballs from host
COPY shared/hadoop-3.4.2.tar.gz /tmp/
COPY shared/apache-zookeeper-3.8.6-bin.tar.gz /tmp/

# Extract Hadoop and ZooKeeper
RUN tar -xzf /tmp/hadoop-3.4.2.tar.gz -C /opt/ && \
    mv /opt/hadoop-3.4.2 /opt/hadoop && \
    tar -xzf /tmp/apache-zookeeper-3.8.6-bin.tar.gz -C /opt/ && \
    mv /opt/apache-zookeeper-3.8.6-bin /opt/zookeeper && \
    rm /tmp/*.tar.gz

# Configure SSH
RUN mkdir -p /root/.ssh && \
    ssh-keygen -t rsa -P '' -f /root/.ssh/id_rsa && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "StrictHostKeyChecking no" >> /root/.ssh/config

# Copy Hadoop config files
# Copy Hadoop & ZooKeeper config files
COPY shared/config/hadoop/core-site.xml      $HADOOP_CONF_DIR/
COPY shared/config/hadoop/hdfs-site.xml      $HADOOP_CONF_DIR/
COPY shared/config/hadoop/yarn-site.xml      $HADOOP_CONF_DIR/
COPY shared/config/hadoop/mapred-site.xml    $HADOOP_CONF_DIR/
COPY shared/config/hadoop/workers            $HADOOP_CONF_DIR/
COPY shared/config/hadoop/hadoop-env.sh      $HADOOP_CONF_DIR/
COPY shared/config/zookeeper/zoo.cfg         $ZOOKEEPER_HOME/conf/

RUN dos2unix $HADOOP_CONF_DIR/* $ZOOKEEPER_HOME/conf/zoo.cfg
# Start SSH on container start
CMD service ssh start && sleep infinity