#!/bin/bash

# node02.sh — Standby NameNode + ZKFC + ResourceManager (Standby), Should only run on node02, AFTER:
#   1. node01.sh ran successfully on node01 (Active NN + ZKFC + RM Active)
#   2. zk-init.sh ran on node01/02/03 (ZooKeeper quorum is up)

set -e

# ── Config ────────────────────────────────────────────────────────────────────
HADOOP_HOME=/opt/hadoop
NAMENODE_DIR=/var/hadoop/namenode
JOURNAL_DIR=/var/hadoop/journal

# ── Helpers ───────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%H:%M:%S')] [node02] $*"; }

check_active_nn() {
  # Check if node01's NameNode RPC port is open
  nc -z node01 8020 2>/dev/null
}

# ── Validate ──────────────────────────────────────────────────────────────────
if [[ "$(hostname)" != "node02" ]]; then
  echo "ERROR: This script must run on node02 only"
  exit 1
fi

log "Starting node02 setup (Standby NameNode + ZKFC + ResourceManager)"

# ── Wait for Active NameNode on node01 ───────────────────────────────────────
log "Waiting for Active NameNode on node01:8020..."
for i in {1..15}; do
  check_active_nn && { log "Active NameNode is reachable"; break; }
  log "Waiting... attempt $i/15"
  sleep 5
  [[ $i -eq 15 ]] && { log "Active NameNode not reachable. Run node01.sh first."; exit 1; }
done

# ── Start JournalNode on node02 ───────────────────────────────────────────────
# log "Creating JournalNode directory"
# mkdir -p $JOURNAL_DIR
# log "Starting JournalNode..."
# $HADOOP_HOME/bin/hdfs --daemon start journalnode
# sleep 3
# log "JournalNode started"

# ── Bootstrap Standby NameNode ────────────────────────────────────────────────
mkdir -p $NAMENODE_DIR

if [[ ! -f $NAMENODE_DIR/current/VERSION ]]; then
  log "Bootstrapping Standby NameNode from Active (node01)..."
  log "This copies NameNode metadata so both NNs have identical state"
  $HADOOP_HOME/bin/hdfs namenode -bootstrapStandby -force
  log "Standby NameNode bootstrapped successfully"
else
  log "Standby NameNode already bootstrapped — skipping"
fi

# ── Start Standby NameNode ────────────────────────────────────────────────────
log "Starting Standby NameNode..."
$HADOOP_HOME/bin/hdfs --daemon start namenode
sleep 3
log "Standby NameNode started"

# ── Start ZKFC ────────────────────────────────────────────────────────────────
log "Starting ZooKeeper Failover Controller..."
$HADOOP_HOME/bin/hdfs --daemon start zkfc
log "ZKFC started"

# ── Start ResourceManager (Standby) ──────────────────────────────────────────
log "Starting ResourceManager (Standby)..."
$HADOOP_HOME/bin/yarn --daemon start resourcemanager
log "ResourceManager started"

# ── Summary ───────────────────────────────────────────────────────────────────
# echo ""
# log "============================================"
# log "node02 services started. Running processes:"
# jps
# log "============================================"
# log "NameNode HA state:"
# $HADOOP_HOME/bin/hdfs haadmin -getServiceState nn2 2>/dev/null || log "(haadmin not ready yet)"
# log "YARN RM HA state:"
# $HADOOP_HOME/bin/yarn rmadmin -getServiceState rm2 2>/dev/null || log "(rmadmin not ready yet)"