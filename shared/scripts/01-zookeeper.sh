#!/bin/bash
# 01-zookeeper.sh — Start ZooKeeper quorum on node01, node02, node03
# Service-centric: this script handles ONLY the ZooKeeper ensemble.

set -e

ZK_DATA_DIR="/var/zookeeper"
ZK_BIN="/opt/zookeeper/bin/zkServer.sh"
ZK_CONF_DIR="/opt/zookeeper/conf"
SHARED_ZK_CFG="/shared/config/zookeeper/zoo.cfg"

ZK_NODES="node01 node02 node03"

log()  { echo "[$(date '+%H:%M:%S')] [ZooKeeper] $*"; }

# ── Assign myid based on hostname ────────────────────────────────────────────
get_myid() {
  case "$1" in
    node01) echo 1 ;;
    node02) echo 2 ;;
    node03) echo 3 ;;
  esac
}

# ── Start ZooKeeper on all quorum nodes ──────────────────────────────────────
for node in $ZK_NODES; do
  MYID=$(get_myid $node)
  log "Initializing ZooKeeper on $node (myid=$MYID)..."

  ssh root@$node bash -s <<REMOTE
    set -e
    mkdir -p $ZK_DATA_DIR
    echo $MYID > $ZK_DATA_DIR/myid

    # Copy zoo.cfg if missing
    if [ ! -f $ZK_CONF_DIR/zoo.cfg ]; then
      cp $SHARED_ZK_CFG $ZK_CONF_DIR/zoo.cfg
    fi

    # Clear stale ZooKeeper PID
    rm -f /tmp/zookeeper_server.pid

    # Start ZooKeeper
    $ZK_BIN start
REMOTE
done

# ── Wait for quorum to stabilize ─────────────────────────────────────────────
sleep 5

# ── Verify quorum ────────────────────────────────────────────────────────────
log "Verifying ZooKeeper quorum..."
for node in $ZK_NODES; do
  MODE=$(ssh root@$node "$ZK_BIN status 2>/dev/null | grep Mode" || echo "  Mode: unknown")
  log "$node: $MODE"
done

log "ZooKeeper ensemble started."
