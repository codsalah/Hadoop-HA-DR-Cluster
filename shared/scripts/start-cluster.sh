#!/bin/bash
# start-cluster.sh — Master Orchestration Script
# Run this from node01 to start the entire cluster in the correct order
#
# Startup Order (ORDER MATTERS):
#   1. ZooKeeper on node01, node02, node03   (must be first)
#   2. JournalNodes on node01, node02, node03 (must be before NN format)
#   3. Format + start Active NameNode on node01
#   4. Bootstrap + start Standby NameNode on node02
#   5. Start DataNodes + NodeManagers on node03, node04, node05

set -e

HADOOP_HOME=/opt/hadoop
ZK_HOME=/opt/zookeeper
SCRIPTS_DIR=/shared/scripts

log() { echo ""; echo "══════════════════════════════════════════════"; echo "  [CLUSTER] $*"; echo "══════════════════════════════════════════════"; }
ok()  { echo "  OK $*"; }
err() { echo "  ERROR: Check Logs $*"; exit 1; }

[[ "$(hostname)" != "node01" ]] && err "start-cluster.sh must be run from node01"

# ── Step 1: Start ZooKeeper on all 3 ZK nodes 
log "STEP 1/5 — Starting ZooKeeper Ensemble"
for node in node01 node02 node03; do
  echo "  → Starting ZooKeeper on $node"
  ssh root@$node "bash $SCRIPTS_DIR/zk-init.sh" &
done
wait
sleep 5

# Verify quorum formed
ok "Verifying ZooKeeper quorum..."
for node in node01 node02 node03; do
  STATUS=$(ssh root@$node "$ZK_HOME/bin/zkServer.sh status 2>/dev/null | grep Mode")
  echo "  $node: $STATUS"
done

# ── Step 2: Start JournalNode on node03 (node01/02 start in their own scripts) 
log "STEP 2/5 — Starting JournalNode on node03"
ssh root@node03 "bash $SCRIPTS_DIR/node03.sh"
ok "node03 JournalNode is up"

# ── Step 3: Start Active NameNode on node01 
log "STEP 3/5 — Starting Active NameNode on node01"
bash $SCRIPTS_DIR/node01.sh
ok "node01 Active NameNode is up"

# ── Step 4: Bootstrap and start Standby NameNode on node02 
log "STEP 4/5 — Starting Standby NameNode on node02"
ssh root@node02 "bash $SCRIPTS_DIR/node02.sh"
ok "node02 Standby NameNode is up"

# ── Step 5: Start worker nodes 
log "STEP 5/5 — Starting Worker Nodes (node04, node05)"
for node in node04 node05; do
  echo "  → Starting DataNode + NodeManager on $node"
  ssh root@$node "bash $SCRIPTS_DIR/workers.sh" &
done
wait
ok "Worker nodes started"

# ── Final Health Check 
log "CLUSTER HEALTH CHECK"
sleep 5

echo ""
echo "  HDFS HA Status:"
$HADOOP_HOME/bin/hdfs haadmin -getServiceState nn1 && echo "  nn1: active" || echo "  nn1: unknown"
$HADOOP_HOME/bin/hdfs haadmin -getServiceState nn2 && echo "  nn2: standby" || echo "  nn2: unknown"

echo ""
echo "  YARN RM HA Status:"
$HADOOP_HOME/bin/yarn rmadmin -getServiceState rm1 || echo "  rm1: unknown"
$HADOOP_HOME/bin/yarn rmadmin -getServiceState rm2 || echo "  rm2: unknown"

echo ""
echo "  HDFS Cluster Report:"
$HADOOP_HOME/bin/hdfs dfsadmin -report | grep -E "Live datanodes|Dead datanodes|DFS Used"

echo ""
ok "Cluster startup complete!"
echo "  HDFS UI  → http://localhost:9871  (node01) / http://localhost:9872  (node02)"
echo "  YARN UI  → http://localhost:8081  (node01) / http://localhost:8082  (node02)"