#!/bin/bash
# 02-journalnodes.sh — Start JournalNode daemons on node01, node02, node03
# Service-centric: this script handles ONLY the HDFS JournalNode layer.

set -e

HADOOP_BIN="/opt/hadoop/bin/hdfs"
JOURNAL_DIR="/var/hadoop/journal"

JN_NODES="node01 node02 node03"

log()  { echo "[$(date '+%H:%M:%S')] [JournalNode] $*"; }

# ── Start JournalNodes in parallel ───────────────────────────────────────────
# Race condition mitigation: mkdir + daemon start chained with && inside a
# single SSH call before backgrounding, so the directory always exists before
# the daemon writes to it.

for node in $JN_NODES; do
  log "Starting JournalNode on $node..."
  ssh root@$node "mkdir -p $JOURNAL_DIR && rm -f /tmp/hadoop-root-journalnode.pid && $HADOOP_BIN --daemon start journalnode" &
done
wait

sleep 3

# ── Verify JournalNodes are listening on port 8485 ───────────────────────────
log "Verifying JournalNode ports..."
for node in $JN_NODES; do
  ssh root@$node "nc -z localhost 8485" 2>/dev/null && \
    log "$node: JournalNode UP (port 8485)" || \
    log "$node: JournalNode NOT READY — check logs"
done

log "JournalNode layer started."
