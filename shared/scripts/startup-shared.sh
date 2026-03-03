#!/bin/bash


SHARED_DIR="$(dirname "$0")/.." 
ZK_TAR="$SHARED_DIR/apache-zookeeper-3.8.6-bin.tar.gz"
HADOOP_TAR="$SHARED_DIR/hadoop-3.4.2.tar.gz"
ZK_URL="https://archive.apache.org/dist/zookeeper/zookeeper-3.8.6/apache-zookeeper-3.8.6-bin.tar.gz"
HADOOP_URL="https://archive.apache.org/dist/hadoop/common/hadoop-3.4.2/hadoop-3.4.2.tar.gz"

if [ -f "$ZK_TAR" ]; then
    echo "ZooKeeper tarball already exists — skipping download"
else
    echo "Downloading ZooKeeper..."
<<<<<<< HEAD
    wget -P "$SHARED_DIR" "$ZK_URL" || { echo "❌ ZooKeeper download failed"; exit 1; }
    echo "ZooKeeper downloaded"
=======
    wget -P "$SHARED_DIR" "$ZK_URL" || { echo "ZooKeeper download failed"; exit 1; }
    echo "✅ ZooKeeper downloaded"
>>>>>>> ac9b7d6 (chore: cleaned up scripts by removing unnecessary parts of the logging process)
fi

if [ -f "$HADOOP_TAR" ]; then
    echo "Hadoop tarball already exists — skipping download"
else
    echo "Downloading Hadoop..."
<<<<<<< HEAD
    wget -P "$SHARED_DIR" "$HADOOP_URL" || { echo "❌ Hadoop download failed"; exit 1; }
    echo "Hadoop downloaded"
=======
    wget -P "$SHARED_DIR" "$HADOOP_URL" || { echo "Hadoop download failed"; exit 1; }
    echo "✅ Hadoop downloaded"
>>>>>>> ac9b7d6 (chore: cleaned up scripts by removing unnecessary parts of the logging process)
fi
echo ""
echo "All downloads complete. You can now run docker-compose up -d"
