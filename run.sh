#!/bin/bash
# /run.sh - Root initialization script for the cluster
# Executed automatically by node01 when the container starts

echo "  [INIT] Starting Master Node Entrypoint"

# 1. Start the local SSH service
service ssh start

echo "  Waiting for worker nodes to start SSH..."
for node in node02 node03 node04 node05; do
    while ! nc -z $node 22 >/dev/null 2>&1; do
        sleep 2
    done
    echo "  [OK] $node is reachable via SSH."
done

echo "  [ORCHESTRATION] All nodes online. Triggering run-all.sh"

# 2. Sanitize and execute the main cluster orchestrator
dos2unix /shared/scripts/*.sh 2>/dev/null
bash /shared/scripts/run-all.sh

echo "  [IDLE] Cluster is running. Keeping container alive."

# 3. Keep node01 container running indefinitely
sleep infinity