#!/bin/bash
<<<<<<< HEAD
# Node01 initialization: Active NameNode, ZKFC, and ResourceManager setup
set -e

# Configuration
HADOOP_HOME=/opt/hadoop
=======

# node01.sh — Active NameNode + ZKFC + ResourceManager (Active)
# Run this ONLY on node01, AFTER:
#   1. ZooKeeper quorum is up (zk-init.sh ran on node01/02/03)
#   2. JournalNodes are up (node03.sh ran on node03)

set -e

# ── Config
HADOOP_HOME=/opt/hadoop
HADOOP_CONF=$HADOOP_HOME/etc/hadoop
>>>>>>> origin/cluster-automation
NAMENODE_DIR=/var/hadoop/namenode
JOURNAL_DIR=/var/hadoop/journal
CLUSTER_ID=clusterA

<<<<<<< HEAD
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [node01] $*"
}

# Environment validation
if [[ "$(hostname)" != "node01" ]]; then
    log "Error: This script must be executed on node01."
    exit 1
fi

log "Starting node01 initialization (Active NameNode + ZKFC + ResourceManager)"

# Dependency check: ZooKeeper Quorum
log "Verifying ZooKeeper availability..."
for i in {1..10}; do
    if echo ruok | nc node01 2181 2>/dev/null | grep -q imok; then
        log "ZooKeeper is online."
        break
    fi
    log "Waiting for ZooKeeper (attempt $i/10)..."
    sleep 5
    if [[ $i -eq 10 ]]; then
        log "Error: ZooKeeper quorum not reachable."
        exit 1
    fi
done

# Initialize Local Directories
log "Initializing local directories."
mkdir -p $JOURNAL_DIR $NAMENODE_DIR

# Start JournalNode
log "Starting JournalNode..."
if ! jps | grep -q JournalNode; then
    $HADOOP_HOME/bin/hdfs --daemon start journalnode
    sleep 3
fi

# NameNode Formatting
if [[ ! -d "$NAMENODE_DIR/current" ]]; then
    log "Formatting NameNode with Cluster ID: $CLUSTER_ID"
    $HADOOP_HOME/bin/hdfs namenode -format -clusterId $CLUSTER_ID -force
else
    log "NameNode already formatted. Skipping."
fi

# ZKFC Initialization
log "Initializing ZooKeeper Failover Controller (ZKFC)..."
$HADOOP_HOME/bin/hdfs zkfc -formatZK -force || true

# Start NameNode
log "Starting NameNode..."
if ! jps | grep -q NameNode; then
    $HADOOP_HOME/bin/hdfs --daemon start namenode
fi

# Wait for NameNode to exit Safe Mode
log "Waiting for NameNode to exit Safe Mode..."
for i in {1..20}; do
    if $HADOOP_HOME/bin/hdfs dfsadmin -safemode get 2>/dev/null | grep -q "OFF"; then
        log "NameNode is out of SAFE MODE."
        break
    fi
    log "NameNode still in SAFE MODE (attempt $i/20)..."
    sleep 5
done

# Start Support Services
log "Starting ZKFC..."
if ! jps | grep -q DFSZKFailoverController; then
    $HADOOP_HOME/bin/hdfs --daemon start zkfc
fi

log "Starting ResourceManager..."
if ! jps | grep -q ResourceManager; then
    $HADOOP_HOME/bin/yarn --daemon start resourcemanager
fi

# Final Status
echo "--------------------------------------------"
log "Initialization complete. Current processes:"
jps
echo "--------------------------------------------"
log "HA Service States:"
$HADOOP_HOME/bin/hdfs haadmin -getServiceState nn1 2>/dev/null || log "haadmin status unavailable"
$HADOOP_HOME/bin/yarn rmadmin -getServiceState rm1 2>/dev/null || log "rmadmin status unavailable"
echo "--------------------------------------------"
=======
# ── Helpers 
log() { echo "[$(date '+%H:%M:%S')] [node01] $*"; }

check_journalnodes() {
  for node in node01 node02 node03; do
    nc -z $node 8485 2>/dev/null || { log " JournalNode not reachable on $node:8485"; return 1; }
  done
  return 0
}

check_zookeeper() {
  echo ruok | nc node01 2181 2>/dev/null | grep -q imok || return 1
}

# ── Validate environment 
if [[ "$(hostname)" != "node01" ]]; then
  echo "ERROR: This script must run on node01 only"
  exit 1
fi

log "Starting node01 setup (Active NameNode + ZKFC + ResourceManager)"

# ── Wait for ZooKeeper quorum
log "Checking ZooKeeper quorum..."
for i in {1..10}; do
  check_zookeeper && { log "✅ ZooKeeper is up"; break; }
  log "Waiting for ZooKeeper... attempt $i/10"
  sleep 5
  [[ $i -eq 10 ]] && { log "ZooKeeper not available. Run zk-init.sh first."; exit 1; }
done

# ── Start JournalNode on node01 
log "Creating JournalNode directory"
mkdir -p $JOURNAL_DIR
log "Starting JournalNode..."
$HADOOP_HOME/bin/hdfs --daemon start journalnode
sleep 3
log "JournalNode started"

# ── Format NameNode (only if not already formatted) 
mkdir -p $NAMENODE_DIR

if [[ ! -f $NAMENODE_DIR/current/VERSION ]]; then
  log "Formatting NameNode with clusterId=$CLUSTER_ID"
  $HADOOP_HOME/bin/hdfs namenode -format -clusterId $CLUSTER_ID -force
  log "NameNode formatted"
else
  log "NameNode already formatted — skipping format"
fi

# ── Initialize ZooKeeper for ZKFC 
log "Initializing ZooKeeper failover controller..."
$HADOOP_HOME/bin/hdfs zkfc -formatZK -force
log "ZooKeeper formatted for ZKFC"

# ── Start NameNode 
log "Starting NameNode..."
$HADOOP_HOME/bin/hdfs --daemon start namenode

log "Waiting for NameNode to exit safe mode..."
for i in {1..20}; do
  sleep 5
  $HADOOP_HOME/bin/hdfs dfsadmin -safemode get 2>/dev/null | grep -q "OFF" && {
    log "NameNode is out of safe mode"
    break
  }
  log "Still in safe mode... attempt $i/20"
done

# ── Start ZKFC 
log "Starting ZooKeeper Failover Controller..."
$HADOOP_HOME/bin/hdfs --daemon start zkfc
log "ZKFC started"

# ── Start ResourceManager (Active)
log "Starting ResourceManager..."
$HADOOP_HOME/bin/yarn --daemon start resourcemanager
log "ResourceManager started"

# ── Summary logging
# echo ""
# log "============================================"
# log "node01 services started. Running processes:"
# jps
# log "============================================"
# log "NameNode HA state:"
# $HADOOP_HOME/bin/hdfs haadmin -getServiceState nn1 2>/dev/null || log "(haadmin not ready yet)"
# log "YARN RM HA state:"
# $HADOOP_HOME/bin/yarn rmadmin -getServiceState rm1 2>/dev/null || log "(rmadmin not ready yet)"
>>>>>>> origin/cluster-automation
