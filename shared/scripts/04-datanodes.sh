#!/bin/bash
# 04-datanodes.sh — Start DataNode daemons on node03, node04, node05
# Service-centric: this script handles ONLY the HDFS DataNode layer.

set -e

HADOOP_BIN="/opt/hadoop/bin/hdfs"
DATANODE_DIR="/var/hadoop/datanode"

DN_NODES="node03 node04 node05"

log()  { echo "[$(date '+%H:%M:%S')] [DataNode] $*"; }

# ── Start DataNodes in parallel ──────────────────────────────────────────────
for node in $DN_NODES; do
  log "Starting DataNode on $node..."
  ssh root@$node "mkdir -p $DATANODE_DIR && rm -f /tmp/hadoop-root-datanode.pid && $HADOOP_BIN --daemon start datanode" &
done
wait

sleep 3

# ── Verify DataNodes are running ─────────────────────────────────────────────
log "Verifying DataNodes..."
for node in $DN_NODES; do
  RUNNING=$(ssh root@$node "jps 2>/dev/null | grep -c DataNode" || echo 0)
  if [[ "$RUNNING" -ge 1 ]]; then
    log "$node: DataNode RUNNING"
  else
    log "$node: DataNode NOT FOUND — check logs"
  fi
done

log "DataNode layer started."
