#!/bin/bash
# 03-namenodes-ha.sh — Format & start Active NameNode (node01), bootstrap & start Standby NameNode (node02)
# Service-centric: this script handles ONLY the HDFS NameNode HA layer.

set -e

HADOOP_BIN="/opt/hadoop/bin/hdfs"
NAMENODE_DIR="/var/hadoop/namenode"
CLUSTER_ID="clusterA"

log()  { echo "[$(date '+%H:%M:%S')] [NameNode-HA] $*"; }

# ══════════════════════════════════════════════════════════════════════════════
#  ACTIVE NAMENODE — node01
# ══════════════════════════════════════════════════════════════════════════════
log "── Active NameNode (node01) ──"

# ── Idempotent format: only if VERSION file does not exist ────────────────────
log "Checking if NameNode is already formatted on node01..."
FORMATTED=$(ssh root@node01 "[ -f $NAMENODE_DIR/current/VERSION ] && echo yes || echo no")

if [[ "$FORMATTED" == "no" ]]; then
  log "Formatting NameNode on node01 (clusterId=$CLUSTER_ID)..."
  ssh root@node01 "mkdir -p $NAMENODE_DIR && $HADOOP_BIN namenode -format -clusterId $CLUSTER_ID -force"
  log "NameNode formatted."
else
  log "NameNode already formatted on node01 — skipping."
fi

# ── Format ZKFC ──────────────────────────────────────────────────────────────
log "Formatting ZKFC in ZooKeeper..."
ssh root@node01 "$HADOOP_BIN zkfc -formatZK -force"
log "ZKFC formatted."

# ── Start Active NameNode ────────────────────────────────────────────────────
log "Starting Active NameNode on node01..."
ssh root@node01 "rm -f /tmp/hadoop-root-namenode.pid && $HADOOP_BIN --daemon start namenode"

# ── Wait for safe mode exit ──────────────────────────────────────────────────
log "Waiting for NameNode to exit safe mode..."
for i in $(seq 1 20); do
  ssh root@node01 "$HADOOP_BIN dfsadmin -safemode get 2>/dev/null" | grep -q "OFF" && {
    log "NameNode is out of safe mode."
    break
  }
  log "Still in safe mode... attempt $i/20"
  sleep 5
done

# ── Start ZKFC on node01 ────────────────────────────────────────────────────
log "Starting ZKFC on node01..."
ssh root@node01 "rm -f /tmp/hadoop-root-zkfc.pid && $HADOOP_BIN --daemon start zkfc"
log "ZKFC started on node01."

# ══════════════════════════════════════════════════════════════════════════════
#  STANDBY NAMENODE — node02
# ══════════════════════════════════════════════════════════════════════════════
log "── Standby NameNode (node02) ──"

# ── Idempotent bootstrap: only if VERSION file does not exist ─────────────────
log "Checking if Standby NameNode is already bootstrapped on node02..."
BOOTSTRAPPED=$(ssh root@node02 "[ -f $NAMENODE_DIR/current/VERSION ] && echo yes || echo no")

if [[ "$BOOTSTRAPPED" == "no" ]]; then
  log "Bootstrapping Standby NameNode from Active (node01)..."
  ssh root@node02 "mkdir -p $NAMENODE_DIR && $HADOOP_BIN namenode -bootstrapStandby -force"
  log "Standby NameNode bootstrapped."
else
  log "Standby NameNode already bootstrapped on node02 — skipping."
fi

# ── Start Standby NameNode ───────────────────────────────────────────────────
log "Starting Standby NameNode on node02..."
ssh root@node02 "rm -f /tmp/hadoop-root-namenode.pid && $HADOOP_BIN --daemon start namenode"
sleep 3
log "Standby NameNode started."

# ── Start ZKFC on node02 ────────────────────────────────────────────────────
log "Starting ZKFC on node02..."
ssh root@node02 "rm -f /tmp/hadoop-root-zkfc.pid && $HADOOP_BIN --daemon start zkfc"
log "ZKFC started on node02."

# ── Verify HA state ──────────────────────────────────────────────────────────
sleep 3
log "NameNode HA Status:"
log "  nn1: $($HADOOP_BIN haadmin -getServiceState nn1 2>/dev/null || echo 'not ready yet')"
log "  nn2: $($HADOOP_BIN haadmin -getServiceState nn2 2>/dev/null || echo 'not ready yet')"

log "NameNode HA layer started."
