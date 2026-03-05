#!/bin/bash

# workers.sh — DataNode + NodeManager for worker nodes (node04, node05)

set -e

# ── Config 
HADOOP_HOME=/opt/hadoop
DATANODE_DIR=/var/hadoop/datanode

# ── Helpers 
HOSTNAME=$(hostname)
log() { echo "[$(date '+%H:%M:%S')] [$HOSTNAME] $*"; }

check_namenode() {
  nc -z node01 8020 2>/dev/null || nc -z node02 8020 2>/dev/null
}

# ── Validate 
if [[ "$HOSTNAME" != "node04" && "$HOSTNAME" != "node05" ]]; then
  echo "ERROR: workers.sh should run on node04 or node05 only"
  exit 1
fi

log "Starting worker node setup (DataNode + NodeManager)"

# ── Create directories 
log "Creating DataNode directory at $DATANODE_DIR"
mkdir -p $DATANODE_DIR

# ── Wait for active NameNode to be reachable 
log "Waiting for an active NameNode to be reachable..."
for i in {1..15}; do
  check_namenode && { log "NameNode is reachable"; break; }
  log "Waiting for NameNode... attempt $i/15"
  sleep 5
  [[ $i -eq 15 ]] && {
    log "NameNode not reachable yet — starting DataNode anyway (it will retry)"
  }
done

# ── Start DataNode 
log "Starting DataNode..."
$HADOOP_HOME/bin/hdfs --daemon start datanode
sleep 2
log "DataNode started"

# ── Start NodeManager 
log "Starting NodeManager..."
$HADOOP_HOME/bin/yarn --daemon start nodemanager
sleep 2
log "NodeManager started"

# ── Summary logging
echo ""
log "============================================"
log "$HOSTNAME services started. Running processes:"
jps
log "============================================"
