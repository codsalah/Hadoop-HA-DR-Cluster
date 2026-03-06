# Hadoop HA — Manual Failover & Resilience Tests

> **Goal**: Kill each primary service one by one, confirm automatic failover to standby, then restore the service before moving to the next test.
>

---

## Test 1 — NameNode Failover (HDFS HA)

> Kill the Active NameNode on node01. ZKFC should detect the failure and automatically promote node02's Standby NameNode to Active.

### Step 1 — Confirm current state

Run from **node01** or **node02**:

```bash
hdfs haadmin -getServiceState nn1
hdfs haadmin -getServiceState nn2
```

→ Expected: `nn1 = active`, `nn2 = standby`

---

### Step 2 — Kill the Active NameNode on node01

SSH into **node01**, then:

```bash
# Find the NameNode PID
jps | grep NameNode

# Kill it hard
kill -9 <NameNode_PID>
```

---

### Step 3 — Watch ZKFC trigger automatic failover

On **node02**, stream the ZKFC log to see the promotion happen in real time:

```bash
tail -f $HADOOP_HOME/logs/*-zkfc-*.log | grep -i "active\|standby\|failover\|transition"
```

→ You should see node02 ZKFC detect the loss of node01's ZK lock and transition nn2 to **active**

---

### Step 4 — Confirm failover succeeded

Run from **node02**:

```bash
hdfs haadmin -getServiceState nn1   # should show: standby or failed to connect
hdfs haadmin -getServiceState nn2   # should show: active
hdfs dfsadmin -report               # confirm cluster is accessible via node02
hdfs dfs -ls /                      # confirm HDFS reads work through new Active
```

---

### Step 5 — Restore NameNode on node01

SSH back into **node01**:

```bash
$HADOOP_HOME/bin/hdfs --daemon start namenode
```

Wait ~15 seconds, then confirm it comes back as **standby**:

```bash
hdfs haadmin -getServiceState nn1   # should show: standby
hdfs haadmin -getServiceState nn2   # should show: active (still)
```

> ✅ Test 1 complete. node01 NameNode is back as Standby. node02 remains Active for now — that's fine, proceed to Test 2.

---

---

## Test 2 — ZKFC Failover (ZooKeeper Failover Controller)

> Kill the ZKFC on node01. Without ZKFC, a node cannot hold or contest the Active ZK lock. The remaining ZKFC on node02 should retain (or take) the Active lock.

### Step 1 — Confirm current HA state

```bash
hdfs haadmin -getServiceState nn1
hdfs haadmin -getServiceState nn2
```

→ Note which is currently active before the test.

---

### Step 2 — Kill ZKFC on node01

SSH into **node01**:

```bash
# Find ZKFC PID
jps | grep DFSZKFailoverController

# Kill it
kill -9 <ZKFC_PID>
```

---

### Step 3 — Observe and confirm

On **node02**:

```bash
# Watch ZKFC log for lock acquisition
tail -f $HADOOP_HOME/logs/*-zkfc-*.log | grep -i "active\|lock\|session\|failover"

# Confirm HA states
hdfs haadmin -getServiceState nn1
hdfs haadmin -getServiceState nn2
```

→ node01's NameNode may transition to **standby** since it lost its ZKFC guardian. node02 should remain or become **active**.

---

### Step 4 — Restore ZKFC on node01

```bash
$HADOOP_HOME/bin/hdfs --daemon start zkfc
```

Confirm it re-registers with ZooKeeper:

```bash
jps | grep DFSZKFailoverController
echo stat | nc localhost 2181        # confirm ZK sees the connection
hdfs haadmin -getServiceState nn1
hdfs haadmin -getServiceState nn2
```

> ✅ Test 2 complete. ZKFC is restored on node01.

---

---

## Test 3 — ResourceManager Failover (YARN HA)

> Kill the Active ResourceManager on node01 (or whichever is currently active). The Standby RM on node02 should automatically take over.

### Step 1 — Confirm current YARN RM state

```bash
yarn rmadmin -getServiceState rm1
yarn rmadmin -getServiceState rm2
```

→ Expected: `rm1 = active`, `rm2 = standby`

---

### Step 2 — Kill the Active ResourceManager on node01

SSH into **node01**:

```bash
# Find PID
jps | grep ResourceManager

# Kill it
kill -9 <ResourceManager_PID>
```

---

### Step 3 — Watch standby RM promote itself

On **node02**, stream the ResourceManager log:

```bash
tail -f $HADOOP_HOME/logs/*-resourcemanager-*.log | grep -i "active\|standby\|transition\|leader"
```

→ node02's RM should detect the loss via ZooKeeper and transition to **active**

---

### Step 4 — Confirm YARN is operational via node02

```bash
yarn rmadmin -getServiceState rm1   # should fail or show: standby
yarn rmadmin -getServiceState rm2   # should show: active

# Verify nodes are still registered
yarn node -list -all

# Optionally submit a quick test job from node03
yarn application -list -appStates ALL
```

---

### Step 5 — Restore ResourceManager on node01

SSH into **node01**:

```bash
$HADOOP_HOME/bin/yarn --daemon start resourcemanager
```

Confirm it comes back as **standby**:

```bash
yarn rmadmin -getServiceState rm1   # should show: standby
yarn rmadmin -getServiceState rm2   # should show: active (still)
```

> ✅ Test 3 complete. ResourceManager restored on node01 as Standby.

---

---

## Test 4 — JournalNode Failure (Quorum Tolerance Test)

> The JournalNode quorum (node01, node02, node03) requires a majority (2 of 3) to be available for HDFS edits to proceed. Kill one JournalNode and confirm HDFS continues writing. Then kill a second to observe the quorum break.

### Step 1 — Confirm all JournalNodes are running

Run on **node01**, **node02**, and **node03** respectively:

```bash
jps | grep JournalNode
```

→ All three should show a JournalNode process.

---

### Step 2 — Kill JournalNode on node03 (lose 1 of 3)

SSH into **node03**:

```bash
jps | grep JournalNode
kill -9 <JournalNode_PID>
```

---

### Step 3 — Confirm HDFS still works (quorum = 2 of 3 still met)

From **node01** or **node02**:

```bash
hdfs dfs -mkdir /test-jn-resilience
hdfs dfs -put /etc/hostname /test-jn-resilience/
hdfs dfs -ls /test-jn-resilience/
```

→ All operations should succeed. HDFS can tolerate losing 1 JournalNode.

---

### Step 4 — Restore JournalNode on node03

SSH into **node03**:

```bash
$HADOOP_HOME/bin/hdfs --daemon start journalnode

# Confirm it synced back with the quorum
tail -n 30 $HADOOP_HOME/logs/*-journalnode-*.log | grep -i "sync\|epoch\|recover"
```

---

### Step 5 — (Optional) Kill a second JournalNode to observe quorum failure

> ⚠️ This will make HDFS **read-only** or stall writes. Only do this in a test environment.

Kill JournalNode on **node02**:

```bash
jps | grep JournalNode
kill -9 <JournalNode_PID>
```

Then attempt a write from any node:

```bash
hdfs dfs -put /etc/hosts /test-jn-resilience/hosts.txt
```

→ This should **hang or fail** — quorum is broken (only 1 of 3 JournalNodes alive)

Restore immediately:

```bash
# On node02
$HADOOP_HOME/bin/hdfs --daemon start journalnode
# On node03 (if not already restored)
$HADOOP_HOME/bin/hdfs --daemon start journalnode
```

> ✅ Test 4 complete. All JournalNodes restored. Clean up test directory:
> ```bash
> hdfs dfs -rm -r /test-jn-resilience
> ```

---

---

## Test 5 — ZooKeeper Node Failure (Quorum Tolerance Test)

> The ZooKeeper ensemble (node01, node02, node03) requires a majority (2 of 3) to elect a leader. Kill ZooKeeper on one node and confirm the ensemble survives.

### Step 1 — Confirm ZooKeeper ensemble status on all three nodes

Run on **node01**, **node02**, **node03**:

```bash
$ZOOKEEPER_HOME/bin/zkServer.sh status
```

→ One node should show `Mode: leader`, others `Mode: follower`

Also check the ensemble from the outside:

```bash
echo mntr | nc localhost 2181 | grep zk_server_state
```

---

### Step 2 — Kill ZooKeeper on node03 (lose 1 of 3 — quorum survives)

SSH into **node03**:

```bash
$ZOOKEEPER_HOME/bin/zkServer.sh stop

# Or hard kill:
jps | grep QuorumPeerMain
kill -9 <ZooKeeper_PID>
```

---

### Step 3 — Confirm ensemble is still healthy (2 of 3 alive)

On **node01** or **node02**:

```bash
$ZOOKEEPER_HOME/bin/zkServer.sh status   # should show leader or follower, not error
echo ruok | nc localhost 2181            # should respond: imok
echo stat | nc localhost 2181 | grep -E "Mode|Connections|Outstanding"
```

→ Confirm HDFS HA and YARN HA are still functioning:

```bash
hdfs haadmin -getServiceState nn1
hdfs haadmin -getServiceState nn2
yarn rmadmin -getServiceState rm1
yarn rmadmin -getServiceState rm2
```

---

### Step 4 — Restore ZooKeeper on node03

SSH into **node03**:

```bash
$ZOOKEEPER_HOME/bin/zkServer.sh start

# Confirm it rejoined the ensemble
$ZOOKEEPER_HOME/bin/zkServer.sh status   # should show: follower
echo ruok | nc node03 2181               # should respond: imok
```

> ✅ Test 5 complete. ZooKeeper ensemble fully restored.

---

---

## Test 6 — DataNode Failure (node04)

> Kill the DataNode on node04. HDFS should detect the loss via missed heartbeats and re-replicate any under-replicated blocks to remaining DataNodes.

### Step 1 — Confirm all DataNodes are live

```bash
hdfs dfsadmin -report | grep -E "Live datanodes|Dead datanodes"
hdfs dfsadmin -report | grep -E "Name:|Hostname:"
```

→ Should show 3 live DataNodes (node03, node04, node05)

---

### Step 2 — Kill the DataNode on node04

SSH into **node04**:

```bash
jps | grep DataNode
kill -9 <DataNode_PID>
```

---

### Step 3 — Monitor HDFS detecting the dead node

From **node01** (Active NameNode). The NameNode waits ~30 seconds (default heartbeat timeout) before marking the node dead:

```bash
# Watch for the node to be marked dead
watch -n 5 "hdfs dfsadmin -report | grep -E 'Live datanodes|Dead datanodes'"

# Monitor NameNode log for replication events
tail -f $HADOOP_HOME/logs/*-namenode-*.log | grep -i "replicat\|dead\|lost\|node04"
```

→ After ~30s: Live datanodes drops to 2, Dead datanodes rises to 1, replication begins

---

### Step 4 — Confirm HDFS is still readable

```bash
hdfs dfs -ls /
hdfs dfs -cat /user/hadoop/wordcount/output/part-r-00000
hdfs dfsadmin -report | grep "Under replicated"
```

---

### Step 5 — Restore DataNode on node04

SSH into **node04**:

```bash
$HADOOP_HOME/bin/hdfs --daemon start datanode

# Watch it re-register and receive block reports
tail -f $HADOOP_HOME/logs/*-datanode-*.log | grep -i "register\|heartbeat\|block report"
```

Confirm from **node01**:

```bash
hdfs dfsadmin -report | grep -E "Live datanodes|Dead datanodes"
# Live should be back to 3
```

> ✅ Test 6 complete. node04 DataNode restored.

---

---

## Test 7 — NodeManager Failure (node05)

> Kill the NodeManager on node05. YARN should detect the loss and stop scheduling containers there. Running applications should continue on remaining nodes.

### Step 1 — Confirm all NodeManagers are registered

```bash
yarn node -list -all
```

→ Should show node03, node04, node05 all in `RUNNING` state

---

### Step 2 — Kill the NodeManager on node05

SSH into **node05**:

```bash
jps | grep NodeManager
kill -9 <NodeManager_PID>
```

---

### Step 3 — Confirm YARN detects the lost node

From **node01** or **node02** (Active RM). YARN marks a node lost after ~10 missed heartbeats (~60s default):

```bash
# Watch node list for node05 to go LOST
watch -n 5 "yarn node -list -all"

# Monitor RM log
tail -f $HADOOP_HOME/logs/*-resourcemanager-*.log | grep -i "node05\|lost\|decommission\|unhealthy"
```

→ node05 should transition to `LOST` state

---

### Step 4 — Submit a test job and confirm it runs on remaining nodes

From **node03**:

```bash
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
  wordcount \
  /user/hadoop/wordcount/input \
  /user/hadoop/wordcount/output2

# Watch which nodes handle the containers
yarn application -list -appStates RUNNING
```

---

### Step 5 — Restore NodeManager on node05

SSH into **node05**:

```bash
$HADOOP_HOME/bin/yarn --daemon start nodemanager

# Confirm re-registration
tail -f $HADOOP_HOME/logs/*-nodemanager-*.log | grep -i "register\|heartbeat"
```

Confirm from **node01**:

```bash
yarn node -list -all   # node05 should be back in RUNNING state
```

> ✅ Test 7 complete. node05 NodeManager restored.

---

---

## Final Cluster Health Check

After all tests are complete, run a full health sweep from **node01**:

```bash
# --- HDFS HA ---
hdfs haadmin -getServiceState nn1
hdfs haadmin -getServiceState nn2

# --- YARN HA ---
yarn rmadmin -getServiceState rm1
yarn rmadmin -getServiceState rm2

# --- All DataNodes live ---
hdfs dfsadmin -report | grep -E "Live datanodes|Dead datanodes|Under replicated"

# --- All YARN nodes running ---
yarn node -list -all

# --- ZooKeeper ensemble healthy ---
echo ruok | nc node01 2181
echo ruok | nc node02 2181
echo ruok | nc node03 2181

# --- JVM processes on each node ---
# (run on each node individually)
jps

# --- Safe mode off ---
hdfs dfsadmin -safemode get
```

→ All checks should return healthy. If HDFS is still in safe mode after restoring services:

```bash
hdfs dfsadmin -safemode leave
```

---

> 🟢 **All HA tests complete.** The cluster has proven automatic failover for NameNode, ResourceManager, and graceful degradation for JournalNode quorum, ZooKeeper quorum, DataNode loss, and NodeManager loss.