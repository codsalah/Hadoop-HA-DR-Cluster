
### Challenge 1 — Windows Line Endings (CRLF) Breaking Shell Scripts

**Description:** All shell scripts were written on a Windows host and committed to Git with CRLF (`\r\n`) line endings. When executed inside Linux containers, Bash interpreted the carriage return as part of each command, causing immediate syntax errors.

**Error:**

```
/shared/scripts/zk-init.sh: line 12: syntax error near unexpected token $'in\r''
```

**Root Cause:** Git on Windows defaults to converting LF to CRLF on checkout. The Linux Bash interpreter does not strip `\r`, so it appears as a literal character in every token on every line.

**Resolution:**

- Fixed existing files in-container: `sed -i 's/\r//' /shared/scripts/*.sh`
- Added `.gitattributes` to enforce LF at the repository level permanently:
    
    ```
    *.sh text eol=lf*.xml text eol=lf*.cfg text eol=lf*.properties text eol=lf
    ```
    
- Added a `sed` sanitization step inside `run-all.sh` as a runtime safety net on every startup.

---

### Challenge 2 — Hadoop Configuration Not Deployed to Nodes

**Description:** Configuration files were stored in the shared volume under `config/hadoop/`, but were never copied into `/opt/hadoop/etc/hadoop/` on any node. Hadoop silently fell back to its defaults.

**Symptoms:**

- NameNode formatted to `/tmp/hadoop-root/dfs/name` instead of `/var/hadoop/namenode`
- ZKFC failed with: `HA is not enabled for this namenode`
- `hdfs getconf -confKey dfs.nameservices` returned an empty string

**Root Cause:** No mechanism existed to push config files from the shared volume to the Hadoop configuration directory. Scripts assumed configs were already in place.

**Resolution:**

- Created `sync-configs.sh` to copy all XML files and `hadoop-env.sh` from shared to `/opt/hadoop/etc/hadoop/` on all 5 nodes and strip Windows line endings in one pass.
- Integrated `sync-configs.sh` as the first step in `run-all.sh`.

---

### Challenge 3 — ZooKeeper `ruok` Command Rejected

**Description:** Health checks used `echo ruok | nc node01 2181` to verify ZooKeeper was up. The command returned nothing, causing false negatives even when ZooKeeper was running correctly.

**Root Cause:** ZooKeeper 3.8.x disabled four-letter word commands (`ruok`, `stat`, `mntr`) by default. The whitelist is empty unless explicitly configured.

**Resolution:**

- Added to `zoo.cfg`: `4lw.commands.whitelist=ruok,mntr,stat`
- Simplified health checks in `run-all.sh` to use `nc -z` (port reachability only), removing the whitelist dependency entirely.

---

### Challenge 4 — netcat Not Installed in Containers

**Description:** Port health checks using `nc -z` failed on all nodes because netcat was not installed in the base `ubuntu:24.04` image. All `wait_for_port` checks silently reported every service as down.

**Resolution:**

- Installed `netcat-openbsd` on all nodes: `apt-get install -y netcat-openbsd -qq`
- Added an automatic `nc` availability check to `run-all.sh` that installs it if missing before any health checks run.

---

### Challenge 5 — JournalNode Quorum Insufficient at NameNode Format Time

**Description:** The NameNode format requires a quorum of JournalNodes before it can proceed. In early script versions, only `node03`'s JournalNode was started before the format step.

**Error:**

```
QuorumException: Unable to check if JNs are ready for formatting.
172.19.0.5:8485: Connection refused
172.19.0.2:8485: Connection refused
```

**Root Cause:** The orchestration order was wrong. `node01.sh` started the JournalNode on `node01` and immediately attempted to format — but format requires 2 of 3 JournalNodes, and only 1 was running.

**Resolution:**

- Restructured `run-all.sh` to start all 3 JournalNodes as a dedicated Phase 3 step, before the NameNode format.
- Added a hard gate that verifies all 3 JournalNodes are listening on port 8485 before proceeding.

---

### Challenge 6 — Stale PID Files Blocking Service Restarts

**Description:** When services were stopped ungracefully (container killed, `kill -9`, or a failed startup), Hadoop left behind PID files in `/tmp/`. On the next startup attempt, the daemon scripts refused to start.

**Error:**

```
journalnode is running as process 8977. Stop it first and ensure
/tmp/hadoop-root-journalnode.pid file is empty before retry.
```

**Resolution:**

- Added a `clear_pid` helper to `run-all.sh` that removes stale PID files before starting each service.
- Called `clear_pid` for every daemon before each start command.

---

### Challenge 7 — Docker DNS Removal on Container Stop

**Description:** When a container was stopped, Docker immediately removed its hostname from the internal DNS. Other containers attempting to resolve that hostname received `UnknownHostException`, preventing the Standby NameNode from taking over as active.

**Error:**

```
java.net.UnknownHostException: node01:8485
Unable to construct journal, qjournal://node01:8485;node02:8485;node03:8485/clusterA
```

**Root Cause:** Docker's embedded DNS is dynamic — it only resolves hostnames for running containers. This is fundamentally different from physical deployments where hostnames persist independently of process state. Since `node01` also ran a JournalNode, stopping the container simultaneously removed hostname resolution and reduced the JournalNode quorum below the required minimum.

**Resolution:**

- Documented that container-level stops are not valid failover tests.
- Validated failover by killing only the NameNode process: `kill -9 $(jps | grep NameNode | cut -d' ' -f1)`
- Proposed static IPs in `docker-compose.yml` and hardcoded `/etc/hosts` entries as a permanent fix.

---

### Challenge 8 — Non-Interactive SSH Shells Not Loading Environment Variables

**Description:** Non-interactive SSH shells on worker nodes did not load `HADOOP_HOME` or other environment variables, causing remote `hdfs` and `yarn` commands to fail silently with `command not found`.

**Resolution:**

- Refactored all scripts to use absolute paths for every remote daemon execution (e.g., `/opt/hadoop/bin/hdfs --daemon start journalnode` instead of `hdfs --daemon start journalnode`).

---

### Challenge 9 — NameNode Enters Safe Mode on Startup [DEPRECATED]

**Description:** After the Active NameNode starts, it enters safe mode and waits for a minimum number of DataNodes to connect before allowing write operations. If workers are slow to start, the NameNode can remain in safe mode longer than expected.

**Resolution:**

- Added a safe mode wait loop in `node01.sh` that polls `hdfs dfsadmin -safemode get` and waits for `OFF` before proceeding.
- If safe mode persists after workers are confirmed running: `hdfs dfsadmin -safemode leave`

---

### Challenge 10 — `depends_on` Does Not Guarantee Service Readiness [DEPRECATED]

**Description:** Docker's `depends_on` directive only guarantees that the dependent **container** has started, not that any service inside it is ready to accept connections. This caused `node01`'s orchestration to attempt SSH connections to other nodes before their SSH daemons were listening, causing immediate failures.

**Resolution:**

- Implemented an SSH polling loop in `run.sh` that retries with a 3-second back-off up to 20 times per node before proceeding to `run-all.sh`.
- All worker nodes (`node02`–`node05`) were updated in `docker-compose.yml` to run `service ssh start && sleep infinity` as their container command.

---

