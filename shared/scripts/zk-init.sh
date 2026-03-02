#!/bin/bash

ZK_DATA_DIR="/var/zookeeper"
ZK_BIN="/opt/zookeeper/bin/zkServer.sh"
ZK_CONF="/opt/zookeeper/conf/zoo.cfg"
NODE_NAME=$(hostname)

mkdir -p "$ZK_DATA_DIR"

case "$NODE_NAME" in
    "node01") echo "1" > "$ZK_DATA_DIR/myid" ;;
    "node02") echo "2" > "$ZK_DATA_DIR/myid" ;;
    "node03") echo "3" > "$ZK_DATA_DIR/myid" ;;
    *) echo "Error: $NODE_NAME is not a ZooKeeper node"; exit 1 ;;
esac

echo "[$NODE_NAME] myid set to $(cat $ZK_DATA_DIR/myid)"

if [ -f "$ZK_CONF" ]; then
    echo "[$NODE_NAME] zoo.cfg already exists — skipping"
else
    echo "[$NODE_NAME] zoo.cfg not found — creating from shared config"
    if [ -f "/shared/config/zookeeper/zoo.cfg" ]; then
        cp /shared/config/zookeeper/zoo.cfg "$ZK_CONF"
        echo "[$NODE_NAME] zoo.cfg copied from shared config"
    else
        echo "Error: zoo.cfg not found at /shared/config/zookeeper/zoo.cfg"
        exit 1
    fi
fi

if [ -f "$ZK_BIN" ]; then
    $ZK_BIN start
else
    echo "Error: zkServer.sh not found at $ZK_BIN"
    exit 1
fi

sleep 3
STATUS=$($ZK_BIN status 2>/dev/null | grep "Mode:")
if [ -n "$STATUS" ]; then
    echo "[$NODE_NAME] ZooKeeper running — $STATUS"
else
    echo "[$NODE_NAME] ZooKeeper failed to start. Check logs at /opt/zookeeper/logs/"
    exit 1
fi