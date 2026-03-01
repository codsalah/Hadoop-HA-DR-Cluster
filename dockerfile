FROM ubuntu:24.04

# Avoid interactive prompts during apt
ENV DEBIAN_FRONTEND=noninteractive

# Install all dependencies in one layer
RUN apt-get update && apt-get install -y \
    openjdk-11-jdk \
    openssh-server \
    openssh-client \
    wget vim net-tools \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
ENV ZOOKEEPER_HOME=/opt/zookeeper
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin

# Copy tarballs from shared (must be in build context)
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
COPY configs/hadoop/core-site.xml      $HADOOP_CONF_DIR/
COPY configs/hadoop/hdfs-site.xml      $HADOOP_CONF_DIR/
COPY configs/hadoop/yarn-site.xml      $HADOOP_CONF_DIR/
COPY configs/hadoop/mapred-site.xml    $HADOOP_CONF_DIR/
COPY configs/hadoop/workers            $HADOOP_CONF_DIR/
COPY configs/hadoop/hadoop-env.sh      $HADOOP_CONF_DIR/

# Start SSH on container start
CMD service ssh start && sleep infinity