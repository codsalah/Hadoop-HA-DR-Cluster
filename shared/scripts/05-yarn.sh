#!/bin/bash
# 05-yarn.sh — Start ResourceManagers (HA) and NodeManagers
# Service-centric: this script handles ONLY the YARN layer.

set -e

YARN_BIN="/opt/hadoop/bin/yarn"

RM_ACTIVE="node01"
RM_STANDBY="node02"
NM_NODES="node03 node04 node05"

log()  { echo "[$(date '+%H:%M:%S')] [YARN] $*"; }

# ── Start Active ResourceManager on node01 ───────────────────────────────────
log "Starting Active ResourceManager on $RM_ACTIVE..."
ssh root@$RM_ACTIVE "rm -f /tmp/hadoop-root-resourcemanager.pid && $YARN_BIN --daemon start resourcemanager"
log "ResourceManager started on $RM_ACTIVE."

# ── Start Standby ResourceManager on node02 ──────────────────────────────────
log "Starting Standby ResourceManager on $RM_STANDBY..."
ssh root@$RM_STANDBY "rm -f /tmp/hadoop-root-resourcemanager.pid && $YARN_BIN --daemon start resourcemanager"
log "ResourceManager started on $RM_STANDBY."

# ── Start NodeManagers in parallel ───────────────────────────────────────────
for node in $NM_NODES; do
  log "Starting NodeManager on $node..."
  ssh root@$node "rm -f /tmp/hadoop-root-nodemanager.pid && $YARN_BIN --daemon start nodemanager" &
done
wait

sleep 3

# ── Verify YARN services ────────────────────────────────────────────────────
log "Verifying YARN HA Status..."
log "  rm1: $($YARN_BIN rmadmin -getServiceState rm1 2>/dev/null || echo 'not ready yet')"
log "  rm2: $($YARN_BIN rmadmin -getServiceState rm2 2>/dev/null || echo 'not ready yet')"

log "Verifying NodeManagers..."
for node in $NM_NODES; do
  RUNNING=$(ssh root@$node "jps 2>/dev/null | grep -c NodeManager" || echo 0)
  if [[ "$RUNNING" -ge 1 ]]; then
    log "$node: NodeManager RUNNING"
  else
    log "$node: NodeManager NOT FOUND — check logs"
  fi
done

log "YARN layer started."
