#!/bin/bash
<<<<<<< HEAD
# Node03 initialization: JournalNode, DataNode, and NodeManager setup
set -e

# Configuration
=======

# node03.sh — JournalNode + DataNode + NodeManager
# node03 is the "bridge" node:
#   - Completes the JournalNode quorum (needs 3: node01, node02, node03)
#   - Completes the ZooKeeper quorum (needs 3: node01, node02, node03)
#   - Also acts as a worker (DataNode + NodeManager)
# Run this BEFORE node01.sh (JournalNodes must be up before NameNode formats)

set -e

# ── Config 
>>>>>>> origin/cluster-automation
HADOOP_HOME=/opt/hadoop
DATANODE_DIR=/var/hadoop/datanode
JOURNAL_DIR=/var/hadoop/journal

<<<<<<< HEAD
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [node03] $*"
}

# Environment validation
if [[ "$(hostname)" != "node03" ]]; then
    log "Error: This script must be executed on node03."
    exit 1
fi

log "Starting node03 initialization (JournalNode + DataNode + NodeManager)"

# Initialize Local Directories
log "Initializing local directories."
mkdir -p $DATANODE_DIR $JOURNAL_DIR

# Start JournalNode
log "Starting JournalNode..."
if ! jps | grep -q JournalNode; then
    $HADOOP_HOME/bin/hdfs --daemon start journalnode
    sleep 3
fi

# Verify JournalNode Port
if nc -z localhost 8485 2>/dev/null; then
    log "JournalNode is online and listening on port 8485."
else
    log "Warning: JournalNode port 8485 is not responding. Check logs for details."
fi

# Start DataNode
log "Starting DataNode..."
if ! jps | grep -q DataNode; then
    $HADOOP_HOME/bin/hdfs --daemon start datanode
fi

# Start NodeManager
log "Starting NodeManager..."
if ! jps | grep -q NodeManager; then
    $HADOOP_HOME/bin/yarn --daemon start nodemanager
fi

# Final Status
echo "--------------------------------------------"
log "Initialization complete. Current processes:"
jps
echo "--------------------------------------------"
=======
# ── Helpers 
log() { echo "[$(date '+%H:%M:%S')] [node03] $*"; }

# ── Validate 
if [[ "$(hostname)" != "node03" ]]; then
  echo "ERROR: This script must run on node03 only"
  exit 1
fi

log "Starting node03 setup (JournalNode + DataNode + NodeManager)"

# ── Create directories 
log "Creating data directories..."
mkdir -p $DATANODE_DIR
mkdir -p $JOURNAL_DIR

# ── Start JournalNode 
#!IMP: JournalNode must start BEFORE the NameNode is formatted
# The NameNode writes its first edit log to JournalNodes during format
log "Starting JournalNode..."
$HADOOP_HOME/bin/hdfs --daemon start journalnode
sleep 3

# Verify JournalNode is listening
nc -z localhost 8485 2>/dev/null && \
  log "JournalNode is up and listening on port 8485" || \
  log "JournalNode may not be ready yet — check logs"

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
log "========================================="
log "node03 services started. Running processes:"
jps
log "=========================================="
>>>>>>> origin/cluster-automation
