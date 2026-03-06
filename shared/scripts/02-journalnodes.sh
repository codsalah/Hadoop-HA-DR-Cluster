#!/bin/bash
# 02-journalnodes.sh — Start JournalNode daemons on node01, node02, node03

set -e

HADOOP_BIN="/opt/hadoop/bin/hdfs"
JOURNAL_DIR="/var/hadoop/journal"

JN_NODES="node01 node02 node03"

log() { echo "[$(date '+%H:%M:%S')] [JournalNode] $*"; }

for node in $JN_NODES; do
  # ── Skip if JournalNode is already running on this node ────────────────────
  ALREADY=$(ssh root@$node "jps 2>/dev/null | grep -c JournalNode" || echo 0)
  if [[ "$ALREADY" -ge 1 ]]; then
    log "$node: JournalNode already running — skipping."
    continue
  fi

  log "Starting JournalNode on $node..."
  ssh root@$node "mkdir -p $JOURNAL_DIR && rm -f /tmp/hadoop-root-journalnode.pid && $HADOOP_BIN --daemon start journalnode" &
done
wait

sleep 3

log "Verifying JournalNode ports..."
for node in $JN_NODES; do
  ssh root@$node "nc -z localhost 8485" 2>/dev/null && \
    log "$node: JournalNode UP (port 8485)" || \
    log "$node: JournalNode NOT READY — check logs"
done

log "JournalNode layer started."
