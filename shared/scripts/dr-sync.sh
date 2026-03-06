#!/bin/bash
# dr-sync.sh — Disaster Recovery Pull Synchronization
# Executes DistCp and Rsync to mirror the Primary Cluster to this DR Cluster.

set -e

HADOOP_BIN="/opt/hadoop/bin/hadoop"
PRIMARY_TAILSCALE_IP="100.75.183.48" # Primary Site VPN IP
PRIMARY_NN="hdfs://node01:8020"
LOCAL_NN="hdfs://dr-node01:8020"

echo "[$(date '+%H:%M:%S')] Starting Disaster Recovery Synchronization..."
# 1. DistCp (HDFS Data Synchronization)
echo "[$(date '+%H:%M:%S')] Initiating DistCp MapReduce job from Primary..."
$HADOOP_BIN distcp "-Ddfs.client.use.datanode.hostname=true" -update -pt $PRIMARY_NN/ $LOCAL_NN/
echo "[$(date '+%H:%M:%S')] DistCp HDFS synchronization complete."
echo "[$(date '+%H:%M:%S')] Waiting for 3 seconds before Rsync..."
sleep 3

# 2. Rsync (OS-Level Metadata Backup)
echo "[$(date '+%H:%M:%S')] Initiating Rsync for NameNode Metadata..."
mkdir -p /shared/dr-backups/namenode/
rsync -avz  -e "ssh -i /shared/dr_rsa_key -o StrictHostKeyChecking=no" --rsync-path="docker exec -i node01 rsync" root@$PRIMARY_TAILSCALE_IP:/var/hadoop/namenode/ /shared/dr-backups/namenode/
