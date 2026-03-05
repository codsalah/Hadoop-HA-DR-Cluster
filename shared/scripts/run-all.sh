#!/bin/bash
# run-all.sh — Cluster orchestrator (Service-Centric Architecture)
# Sequentially executes service scripts with network dependency polling between phases.
# Run from node01.

set -e

SCRIPTS_DIR=/shared/scripts
HADOOP_BIN=/opt/hadoop/bin/hdfs
YARN_BIN=/opt/hadoop/bin/yarn
ZK_BIN=/opt/zookeeper/bin/zkServer.sh

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "[$(date '+%H:%M:%S')] OK: $*"; }
fail() { echo "[$(date '+%H:%M:%S')] FAIL: $*"; exit 1; }

wait_for_port() {
  local host=$1 port=$2 label=$3
  for i in $(seq 1 15); do
    ssh root@$host "nc -z $host $port" 2>/dev/null && { ok "$label up on $host:$port"; return 0; }
    sleep 3
  done
  fail "$label did not come up on $host:$port"
}

# ── Pre-flight ────────────────────────────────────────────────────────────────
[[ "$(hostname)" == "node01" ]] || fail "Must run from node01"

log "Fixing line endings and permissions on all scripts..."
for node in node01 node02 node03 node04 node05; do
  ssh root@$node "sed -i 's/\r//' $SCRIPTS_DIR/*.sh && chmod +x $SCRIPTS_DIR/*.sh"
done

# ── Sync configs ─────────────────────────────────────────────────────────────
[[ -f "$SCRIPTS_DIR/sync-conf.sh" ]] || fail "sync-conf.sh not found in $SCRIPTS_DIR"
log "Syncing configs to all nodes..."
bash $SCRIPTS_DIR/sync-conf.sh
ok "Configs synced"

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 1/5 — ZooKeeper Ensemble
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 1/5 — ZooKeeper"
bash $SCRIPTS_DIR/01-zookeeper.sh

for node in node01 node02 node03; do
  wait_for_port $node 2181 "ZooKeeper"
done

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 2/5 — JournalNodes
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 2/5 — JournalNodes"
bash $SCRIPTS_DIR/02-journalnodes.sh

for node in node01 node02 node03; do
  wait_for_port $node 8485 "JournalNode"
done

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 3/5 — NameNode HA (Active + Standby + ZKFC)
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 3/5 — NameNode HA"
bash $SCRIPTS_DIR/03-namenodes-ha.sh

wait_for_port node01 8020 "Active NameNode"
wait_for_port node02 8020 "Standby NameNode"

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 4/5 — DataNodes
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 4/5 — DataNodes"
bash $SCRIPTS_DIR/04-datanodes.sh

sleep 5

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 5/5 — YARN (ResourceManagers + NodeManagers)
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 5/5 — YARN"
bash $SCRIPTS_DIR/05-yarn.sh

sleep 5

# ══════════════════════════════════════════════════════════════════════════════
#  CLUSTER HEALTH SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
log "==== CLUSTER HEALTH ===="
log "nn1: $($HADOOP_BIN haadmin -getServiceState nn1 2>/dev/null || echo unreachable)"
log "nn2: $($HADOOP_BIN haadmin -getServiceState nn2 2>/dev/null || echo unreachable)"
log "rm1: $($YARN_BIN rmadmin -getServiceState rm1 2>/dev/null || echo unreachable)"
log "rm2: $($YARN_BIN rmadmin -getServiceState rm2 2>/dev/null || echo unreachable)"
$HADOOP_BIN dfsadmin -report 2>/dev/null | grep "Live datanodes"
for node in node01 node02 node03 node04 node05; do
  PROCS=$(ssh root@$node "jps 2>/dev/null | grep -v Jps | awk '{print \$2}' | tr '\n' ' '" 2>/dev/null)
  log "$node: $PROCS"
done