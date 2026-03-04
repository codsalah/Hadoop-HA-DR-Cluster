#!/bin/bash
# run-all.sh — Cluster orchestrator. Calls existing scripts in correct order.
# Run from node01.

set -e

SCRIPTS_DIR=/shared/scripts
HADOOP_HOME=/opt/hadoop
ZK_HOME=/opt/zookeeper
JOURNAL_DIR=/var/hadoop/journal

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

# ── Sync and verify configs ───────────────────────────────────────────────────
[[ -f "$SCRIPTS_DIR/sync-conf.sh" ]] || fail "sync-conf.sh not found in $SCRIPTS_DIR"
log "Syncing configs to all nodes..."
bash $SCRIPTS_DIR/sync-conf.sh
ok "Configs synced"

# ── Step 1: ZooKeeper ─────────────────────────────────────────────────────────
log "STEP 1/5 — ZooKeeper"
for node in node01 node02 node03; do
  ssh root@$node "bash $SCRIPTS_DIR/zk-init.sh" &
done
wait
sleep 3

for node in node01 node02 node03; do
  MODE=$(ssh root@$node "$ZK_HOME/bin/zkServer.sh status 2>/dev/null | grep Mode" || echo "unknown")
  log "$node: $MODE"
done

# ── Step 2: node03 (JournalNode must be up before NameNode formats) ───────────
log "STEP 2/5 — node03 (JournalNode + DataNode + NodeManager)"
ssh root@node03 "bash $SCRIPTS_DIR/node03.sh" &

ssh root@node02 "mkdir -p $JOURNAL_DIR && $HADOOP_HOME/bin/hdfs --daemon start journalnode" &

# Wait for both JournalNodes to be ready before moving on
wait_for_port node03 8485 "JournalNode node03"
wait_for_port node02 8485 "JournalNode node02"

# ── Step 3: node01 (Active NameNode + ZKFC + ResourceManager) ────────────────
log "STEP 3/5 — node01 (Active NameNode + ZKFC + ResourceManager)"
bash $SCRIPTS_DIR/node01.sh
ok "nn1: $($HADOOP_HOME/bin/hdfs haadmin -getServiceState nn1 2>/dev/null)"

# ── Step 4: node02 (Standby NameNode + ZKFC + ResourceManager) ───────────────
log "STEP 4/5 — node02 (Standby NameNode + ZKFC + ResourceManager)"
ssh root@node02 "bash $SCRIPTS_DIR/node02.sh"
ok "nn2: $($HADOOP_HOME/bin/hdfs haadmin -getServiceState nn2 2>/dev/null)"

# ── Step 5: Workers (node04, node05) ─────────────────────────────────────────
log "STEP 5/5 — Workers (node04, node05)"
for node in node04 node05; do
  ssh root@$node "bash $SCRIPTS_DIR/workers.sh" &
done
wait
sleep 8

# ── Summary ───────────────────────────────────────────────────────────────────
log "==== CLUSTER HEALTH ===="
log "nn1: $($HADOOP_HOME/bin/hdfs haadmin -getServiceState nn1 2>/dev/null || echo unreachable)"
log "nn2: $($HADOOP_HOME/bin/hdfs haadmin -getServiceState nn2 2>/dev/null || echo unreachable)"
log "rm1: $($HADOOP_HOME/bin/yarn rmadmin -getServiceState rm1 2>/dev/null || echo unreachable)"
log "rm2: $($HADOOP_HOME/bin/yarn rmadmin -getServiceState rm2 2>/dev/null || echo unreachable)"
$HADOOP_HOME/bin/hdfs dfsadmin -report 2>/dev/null | grep "Live datanodes"
for node in node01 node02 node03 node04 node05; do
  PROCS=$(ssh root@$node "jps 2>/dev/null | grep -v Jps | awk '{print \$2}' | tr '\n' ' '" 2>/dev/null)
  log "$node: $PROCS"
done