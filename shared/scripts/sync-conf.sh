#!/bin/bash
# sync-configs.sh — Distributes and sanitizes configs across the cluster
# Run this from node01 whenever you change an XML or .sh config file on your Windows host.

set -e

HADOOP_CONF_DIR="/opt/hadoop/etc/hadoop"
ZK_CONF_DIR="/opt/zookeeper/conf"
SHARED_HADOOP="/shared/config/hadoop"
SHARED_ZK="/shared/config/zookeeper"



# Ensure script is run from node01
if [[ "$(hostname)" != "node01" ]]; then
  echo "ERROR: Please run sync-configs.sh from node01."
  exit 1
fi

for node in node01 node02 node03 node04 node05; do
  echo "  → Syncing $node..."
  
  # 1. Copy Hadoop Configs
  ssh root@$node "cp $SHARED_HADOOP/* $HADOOP_CONF_DIR/ 2>/dev/null || true"
  
  # 2. Sanitize Windows CRLF to Linux LF
  ssh root@$node "dos2unix $HADOOP_CONF_DIR/*.xml $HADOOP_CONF_DIR/*.sh $HADOOP_CONF_DIR/workers 2>/dev/null || true"

  # 3. Copy ZooKeeper Configs (Only needed on ZK nodes)
  if [[ "$node" == "node01" || "$node" == "node02" || "$node" == "node03" ]]; then
    ssh root@$node "cp $SHARED_ZK/zoo.cfg $ZK_CONF_DIR/ 2>/dev/null || true"
    ssh root@$node "dos2unix $ZK_CONF_DIR/zoo.cfg 2>/dev/null || true"
  fi

  echo "    $node complete"
done

echo ""
echo "  All configurations synced and sanitized successfully!"
