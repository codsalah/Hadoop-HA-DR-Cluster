#!/bin/bash
# 03-namenodes-ha.sh — Format & start Active NameNode (node01), bootstrap & start Standby NameNode (node02)

set -e

HADOOP_BIN="/opt/hadoop/bin/hdfs"
NAMENODE_DIR="/var/hadoop/namenode"
CLUSTER_ID="clusterA"

log() { echo "[$(date '+%H:%M:%S')] [NameNode-HA] $*"; }

# ══════════════════════════════════════════════════════════════════════════════
#  ACTIVE NAMENODE — node01
# ══════════════════════════════════════════════════════════════════════════════
log "── Active NameNode (node01) ──"

FORMATTED=$(ssh root@node01 "[ -f $NAMENODE_DIR/current/VERSION ] && echo yes || echo no")
if [[ "$FORMATTED" == "no" ]]; then
  log "Formatting NameNode on node01 (clusterId=$CLUSTER_ID)..."
  ssh root@node01 "mkdir -p $NAMENODE_DIR && $HADOOP_BIN namenode -format -clusterId $CLUSTER_ID -force"
  log "NameNode formatted."
else
  log "NameNode already formatted on node01 — skipping."
fi

log "Formatting ZKFC in ZooKeeper..."
ssh root@node01 "$HADOOP_BIN zkfc -formatZK -force"

# ── Skip NameNode start if already running ────────────────────────────────────
NN1_RUNNING=$(ssh root@node01 "jps 2>/dev/null | grep -c NameNode" || echo 0)
if [[ "$NN1_RUNNING" -ge 1 ]]; then
  log "node01: NameNode already running — skipping."
else
  log "Starting Active NameNode on node01..."
  ssh root@node01 "rm -f /tmp/hadoop-root-namenode.pid && $HADOOP_BIN --daemon start namenode"
fi

log "Waiting for NameNode to exit safe mode..."
for i in $(seq 1 20); do
  ssh root@node01 "$HADOOP_BIN dfsadmin -safemode get 2>/dev/null" | grep -q "OFF" && {
    log "NameNode is out of safe mode."
    break
  }
  log "Still in safe mode... attempt $i/20"
  sleep 5
done

# ── Skip ZKFC start if already running ───────────────────────────────────────
ZKFC1_RUNNING=$(ssh root@node01 "jps 2>/dev/null | grep -c DFSZKFailoverController" || echo 0)
if [[ "$ZKFC1_RUNNING" -ge 1 ]]; then
  log "node01: ZKFC already running — skipping."
else
  log "Starting ZKFC on node01..."
  ssh root@node01 "rm -f /tmp/hadoop-root-zkfc.pid && $HADOOP_BIN --daemon start zkfc"
  log "ZKFC started on node01."
fi

# ══════════════════════════════════════════════════════════════════════════════
#  STANDBY NAMENODE — node02
# ══════════════════════════════════════════════════════════════════════════════
log "── Standby NameNode (node02) ──"

BOOTSTRAPPED=$(ssh root@node02 "[ -f $NAMENODE_DIR/current/VERSION ] && echo yes || echo no")
if [[ "$BOOTSTRAPPED" == "no" ]]; then
  log "Bootstrapping Standby NameNode from Active (node01)..."
  ssh root@node02 "mkdir -p $NAMENODE_DIR && $HADOOP_BIN namenode -bootstrapStandby -force"
  log "Standby NameNode bootstrapped."
else
  log "Standby NameNode already bootstrapped on node02 — skipping."
fi

# ── Skip NameNode start if already running ────────────────────────────────────
NN2_RUNNING=$(ssh root@node02 "jps 2>/dev/null | grep -c NameNode" || echo 0)
if [[ "$NN2_RUNNING" -ge 1 ]]; then
  log "node02: NameNode already running — skipping."
else
  log "Starting Standby NameNode on node02..."
  ssh root@node02 "rm -f /tmp/hadoop-root-namenode.pid && $HADOOP_BIN --daemon start namenode"
  sleep 3
  log "Standby NameNode started."
fi

# ── Skip ZKFC start if already running ───────────────────────────────────────
ZKFC2_RUNNING=$(ssh root@node02 "jps 2>/dev/null | grep -c DFSZKFailoverController" || echo 0)
if [[ "$ZKFC2_RUNNING" -ge 1 ]]; then
  log "node02: ZKFC already running — skipping."
else
  log "Starting ZKFC on node02..."
  ssh root@node02 "rm -f /tmp/hadoop-root-zkfc.pid && $HADOOP_BIN --daemon start zkfc"
  log "ZKFC started on node02."
fi

sleep 3
log "NameNode HA Status:"
log "  nn1: $($HADOOP_BIN haadmin -getServiceState nn1 2>/dev/null || echo 'not ready yet')"
log "  nn2: $($HADOOP_BIN haadmin -getServiceState nn2 2>/dev/null || echo 'not ready yet')"

log "NameNode HA layer started."
