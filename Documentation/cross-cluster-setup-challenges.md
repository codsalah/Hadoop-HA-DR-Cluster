# Cross-Cluster DR Setup Challenges

## 1. Tailscale SSH Interference

### The Challenge

Native SSH connection attempts were blocked because **Tailscale's built-in SSH feature hijacked the authentication flow** between machines.

### The Solution

Disabled **Tailscale SSH** completely and routed communication through **standard SSH connections exposed via Docker Compose port mappings**.

---

## 2. High Availability (HA) Target Resolution

### The Challenge

In a **Hadoop HA setup**, attempting to sync with a **Standby NameNode** results in a `StandbyException`.

Hardcoding NameNode addresses fails if **ZooKeeper elects a different Active leader**.

### The Solution

Implemented a **dynamic "NameNode Hunter"** Bash logic that probes both NameNodes and identifies the currently **Active leader** before any data transfer begins.

```bash
# Dynamic NameNode Hunter Logic

if hdfs dfs -ls hdfs://node01:8020/ > /dev/null 2>&1; then
    PRIMARY_NN="node01"

elif hdfs dfs -ls hdfs://node02:8020/ > /dev/null 2>&1; then
    PRIMARY_NN="node02"

else
    echo "CRITICAL ERROR: No Active NameNode found!"
    exit 1
fi
```

---

## 3. Cross-Environment SSH Authentication

### The Challenge

`rsync` requires SSH authentication.

However, SSH authenticates against the **physical host machines over the VPN**, not the **Docker containers that store the actual Hadoop data**.

### The Solution

Injected the **host SSH key** into the container through a **Docker volume**, and used a custom `--rsync-path` to force the SSH session to:

1. Connect to the **physical Linux host**
2. Immediately execute `rsync` **inside the target container**

```bash
rsync -avz \
-e "ssh -i /shared/dr_rsa_key -o StrictHostKeyChecking=no" \
--rsync-path="docker exec -i $PRIMARY_NN rsync" \
root@$PRIMARY_TAILSCALE_IP:/var/hadoop/namenode/ \
/shared/dr-backups/namenode/
```

---

## 4. The Ephemeral Automation Trap (Cron vs Task Scheduler)

### The Challenge

Running **cron inside Docker containers** failed as a long-term automation solution because containers are **ephemeral**.

Rebuilding the cluster would **destroy the cron configuration**.

Additionally, running **Linux cron directly on a Windows host** is not practical without virtualization.

### The Solution

Moved the orchestration layer **outside the containers entirely**.

Containers are treated strictly as **ephemeral compute nodes**, while scheduling is handled by the **Windows host using Windows Task Scheduler**.

```powershell
# Register persistent background automation on the host

$Action = New-ScheduledTaskAction -Execute $batPath
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
            -RepetitionInterval (New-TimeSpan -Minutes 5)

Register-ScheduledTask `
  -TaskName "Hadoop-DR-Sync" `
  -Trigger $Trigger `
  -Action $Action
```

---

## 5. Rsync Version Mismatch

### The Challenge

Synchronization failed because the **DR node** and **Active cluster containers** were running **different rsync versions**.

### The Solution

Standardized the environment by **installing rsync directly in the Dockerfile for both clusters**, guaranteeing version compatibility during builds.

---

## 6. Cross-Cluster DataNode Routing (`BlockMissingException`)

### The Challenge

The `DistCp` MapReduce job successfully submitted and completed progress to **100%**, but failed during block reads with:

```
BlockMissingException: No live nodes contain current block
```

The issue occurred because **DataNodes reported internal Docker IPs (e.g., `172.18.x.x`)**, which the **other cluster could not route to**.

### The Solution

Forced **DistCp** to use **resolvable hostnames instead of Docker IP addresses** by injecting the following configuration flag.

```bash
/opt/hadoop/bin/hadoop distcp \
-Ddfs.client.use.datanode.hostname=true \
-update -pt \
hdfs://${PRIMARY_NN}:8020/ \
hdfs://${DR_NN}:8020/
```

This forces Hadoop clients to **connect using hostnames instead of container network IPs**, enabling proper cross-cluster routing.



