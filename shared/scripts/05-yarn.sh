#!/bin/bash
# 05-yarn.sh — Start ResourceManagers (HA) and NodeManagers

set -e

YARN_BIN="/opt/hadoop/bin/yarn"

RM_ACTIVE="node01"
RM_STANDBY="node02"
NM_NODES="node03 node04 node05"

log() { echo "[$(date '+%H:%M:%S')] [YARN] $*"; }

# ── Skip if Active ResourceManager is already running ────────────────────────
RM1_RUNNING=$(ssh root@$RM_ACTIVE "jps 2>/dev/null | grep -c ResourceManager" || echo 0)
if [[ "$RM1_RUNNING" -ge 1 ]]; then
  log "$RM_ACTIVE: ResourceManager already running — skipping."
else
  log "Starting Active ResourceManager on $RM_ACTIVE..."
  ssh root@$RM_ACTIVE "rm -f /tmp/hadoop-root-resourcemanager.pid && $YARN_BIN --daemon start resourcemanager"
  log "ResourceManager started on $RM_ACTIVE."
fi

# ── Skip if Standby ResourceManager is already running ───────────────────────
RM2_RUNNING=$(ssh root@$RM_STANDBY "jps 2>/dev/null | grep -c ResourceManager" || echo 0)
if [[ "$RM2_RUNNING" -ge 1 ]]; then
  log "$RM_STANDBY: ResourceManager already running — skipping."
else
  log "Starting Standby ResourceManager on $RM_STANDBY..."
  ssh root@$RM_STANDBY "rm -f /tmp/hadoop-root-resourcemanager.pid && $YARN_BIN --daemon start resourcemanager"
  log "ResourceManager started on $RM_STANDBY."
fi

# ── Skip NodeManagers that are already running ────────────────────────────────
for node in $NM_NODES; do
  ALREADY=$(ssh root@$node "jps 2>/dev/null | grep -c NodeManager" || echo 0)
  if [[ "$ALREADY" -ge 1 ]]; then
    log "$node: NodeManager already running — skipping."
    continue
  fi

  log "Starting NodeManager on $node..."
  ssh root@$node "rm -f /tmp/hadoop-root-nodemanager.pid && $YARN_BIN --daemon start nodemanager" &
done
wait

sleep 3

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
