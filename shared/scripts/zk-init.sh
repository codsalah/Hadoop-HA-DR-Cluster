#!/bin/bash

# Configuration
ZK_DATA_DIR="/var/zookeeper"
ZK_BIN="/opt/zookeeper/bin/zkServer.sh"
NODE_NAME=$(hostname)

#  Initialize data directory
mkdir -p "$ZK_DATA_DIR"

# Assign ID based on hostname
case "$NODE_NAME" in
    "node01") echo "1" > "$ZK_DATA_DIR/myid" ;;
    "node02") echo "2" > "$ZK_DATA_DIR/myid" ;;
    "node03") echo "3" > "$ZK_DATA_DIR/myid" ;;
    *) exit 0 ;;
esac

# Start Service
if [ -f "$ZK_BIN" ]; then
    $ZK_BIN start
else
    echo "Error: zkServer.sh not found at $ZK_BIN"
    exit 1
fi