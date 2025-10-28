# notes

## audio separation

- https://asteroid-team.github.io/

## observability

- https://www.selfping.com/
- https://healthchecks.io/
- https://github.com/healthyhost/audit-vps-script

### monitoring

```sh
#!/bin/bash
BOT_TOKEN="<telegram-bot-token>"
CHAT_ID="<telegram-chat-id>"
USERNAME="@<telegram-username>"

send_telegram_message() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$message" \
    -d parse_mode="HTML"
}

process_container_event() {
  local status="$1"
  local container="$2"
  local exit_code="$3"

  local message
  if [[ "$status" == "start" ]]; then
    message="✅ Container started: ${container}"
  else
    [[ -z "$exit_code" ]] && exit_code="N/A"
    message="💀 Container died: ${container} (${exit_code}) ${USERNAME}"
  fi

  send_telegram_message "$message"
}

docker events \
  --filter 'type=container' \
  --filter 'event=die' \
  --filter 'event=start' \
  --format '{{.Status}} {{.Actor.Attributes.name}} {{.Actor.Attributes.exitCode}}' | \
  while read -r status container exit_code; do
    process_container_event "$status" "$container" "$exit_code"
  done
```
```sh
# /etc/systemd/system/monitor-containers.service

[Unit]
Description=Monitor Docker containers
After=docker.service
Wants=docker.service

[Service]
ExecStart=/home/user/scripts/monitor-containers.sh
Restart=always
User=user

[Install]
WantedBy=multi-user.target
```

### contexts
```sh
# Running Docker commands remotely

# Create new context for remote VPS
docker context create vps \
  --docker "host=ssh://user@12.34.56.78"

# List available contexts
docker context ls
# NAME     DESCRIPTION   DOCKER ENDPOINT
# default  *             unix:///var/run/docker.sock
# vps                    ssh://user@12.34.56.78

# Switch to remote context
docker context use vps

# Run command on remote host
docker ps
# CONTAINER ID  IMAGE  COMMAND  STATUS         PORTS
# abc123def     app    "npm"    Up 15 minutes  80/tcp

# Switch back to local when needed
docker context use default
```

### backups

```sh
#!/bin/bash -x
set -e

HEALTHCHECKS_URL="https://hc-ping.com/<id>"
BACKUP_NAME="pg_dump-$(date +%d-%H).sql.gz"

pg_dump -h localhost -p 5432 -U postgres \
  main | gzip > "/tmp/${BACKUP_NAME}"

aws s3 cp "/tmp/${BACKUP_NAME}" "s3://bucket/${BACKUP_NAME}"
rm "/tmp/${BACKUP_NAME}"

curl -fsS -m 10 --retry 5 -o /dev/null "$HEALTHCHECKS_URL"
```
```sh
# Run hourly automatically
# crontab -e
0 * * * * /home/user/backup_pg.sh >> /home/user/backup.log 2>&1
```

### disk

```sh
#!/usr/bin/env bash

BOT_TOKEN="<telegram-bot-token>"
CHAT_ID="<telegram-chat-id>"

send_telegram_message() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$message" \
    -d parse_mode="HTML"
}

DISK_THRESHOLD=80
IGNORE_FS="tmpfs|devtmpfs|efivarfs" # Filesystems to ignore

check_disk_utilization() {
  df -h | grep -vE "^Filesystem|${IGNORE_FS}" | while read -r line; do
    filesystem=$(echo "$line" | awk '{print $1}')
    mount_point=$(echo "$line" | awk '{print $6}')
    usage_percent=$(echo "$line" | awk '{print $5}' | sed 's/%//')

    if (( usage_percent > DISK_THRESHOLD )); then
      local message="🚨 <b>High Disk Usage Alert</b> 🚨%0A"
      message+="<b>Filesystem:</b> ${filesystem}%0A"
      message+="<b>Mount Point:</b> ${mount_point}%0A"
      message+="<b>Usage:</b> ${usage_percent}%%0A"

      send_telegram_message "$message"
    fi
  done
}

check_disk_utilization
```
```sh
# crontab -e
*/5 * * * * /home/user/monitor-disk.sh
```
```sh
#!/usr/bin/env bash

HEALTHCHECKS_URL="https://hc-ping.com/<id>"
BOT_TOKEN="<telegram-bot-token>"
CHAT_ID="<telegram-chat-id>"

send_telegram_message() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$message" \
    -d parse_mode="HTML"
}

DISK_THRESHOLD=80
IGNORE_FS="tmpfs|devtmpfs|efivarfs" # Filesystems to ignore

check_disk_utilization() {
  df -h | grep -vE "^Filesystem|${IGNORE_FS}" | while read -r line; do
    filesystem=$(echo "$line" | awk '{print $1}')
    mount_point=$(echo "$line" | awk '{print $6}')
    usage_percent=$(echo "$line" | awk '{print $5}' | sed 's/%//')

    if (( usage_percent > DISK_THRESHOLD )); then
      local message="🚨 <b>High Disk Usage Alert</b> 🚨%0A"
      message+="<b>Filesystem:</b> ${filesystem}%0A"
      message+="<b>Mount Point:</b> ${mount_point}%0A"
      message+="<b>Usage:</b> ${usage_percent}%%0A"

      send_telegram_message "$message"
    fi
  done
}

check_disk_utilization

curl -fsS -m 10 --retry 5 -o /dev/null "$HEALTHCHECKS_URL"
```

### CPU

```sh
#!/usr/bin/env bash
# /usr/local/bin/send_telegram_message

BOT_TOKEN="<telegram-bot-token>"
CHAT_ID="<telegram-chat-id>"

send_telegram_message() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$message" \
    -d parse_mode="HTML"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -eq 1 ]]; then
    send_telegram_message "$1"
  else
    echo "Usage: $0 <message>"
    exit 1
  fi
fi
```

### application errors

```sh
#!/usr/bin/env bash
# monitor_systemd_logs.sh

SERVICES=(
  "app1.service"
  "app2.service"
  "app3.service"
)

cmd="journalctl"
for service in "${SERVICES[@]}"; do
  cmd+=" -u $service"
done
cmd+=" -f -o json --output-fields=_SYSTEMD_UNIT,MESSAGE"

eval "$cmd" | while read -r line; do
  if echo "$line" | grep -qwi "error"; then
    unit=$(echo "$line" | jq -r '._SYSTEMD_UNIT')
    log=$(echo "$line" | jq -r '.MESSAGE')

    message="🚨 <b>Error Alert</b> 🚨%0A"
    message+="<b>Service:</b> $unit%0A"
    message+="<b>Log:</b> $log%0A"

    send_telegram_message "$message"
  fi
done
```
```sh
# monitor_systemd_logs.service

[Unit]
Description=Systemd log monitor

[Service]
ExecStart=/home/user/monitor_systemd_logs.sh
Restart=always
User=user

[Install]
WantedBy=multi-user.target
```

### container errors

```sh
#!/bin/bash
# monitor-docker-logs.sh

BOT_TOKEN="<telegram-bot-token>"
CHAT_ID="<telegram-chat-id>"

send_telegram_message() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$message" \
    -d parse_mode="HTML"
}

CONTAINERS=$(docker ps --format '{{.Names}}')
KEYWORDS=("error" "fail" "crash" "fatal" "panic")

monitor_container() {
  local container=$1
  docker logs --tail 0 -f "$container" | while read -r line; do
    for keyword in "${KEYWORDS[@]}"; do
      if echo "$line" | grep -qi "$keyword"; then
        local message="🐳 <b>Docker Alert: $container</b> 🚨%0A"
        message+="<b>Time:</b> $(date '+%Y-%m-%d %H:%M:%S')%0A"
        message+="<b>Log:</b> ${line}%0A"

        send_telegram_message "$message"
        break
      fi
    done
  done
}

for container in $CONTAINERS; do
  monitor_container "$container" &
done

wait
```

```sh
# monitor-docker-logs.service

[Unit]
Description=Monitors logs of Docker containers
After=docker.service
Wants=docker.service

[Service]
ExecStart=/home/user/scripts/monitor-docker-logs.sh
Restart=always
User=user

[Install]
WantedBy=multi-user.target
```

## operations research

Short answer: yes for “context”, not really for “fleet”.

* **Docker context → Podman’s equivalent is `podman system connection`**.
  You create named remote connections (usually over SSH to each host’s Podman socket) and then target them with the CLI. Example:

  ```bash
  # on your laptop
  podman system connection add prod ssh://root@prod1.example.com/run/podman/podman.sock
  podman system connection add staging ssh://fedora@stg1.example.com/run/podman/podman.sock
  podman system connection default prod
  podman --connection prod ps
  podman --connection staging images
  ```

  That subcommand family lets you `add`, `list`, `default`, `rename`, and `remove` connections, i.e., it fills the “context” role. ([Podman Documentation][1])

* **Docker “fleet”/Swarm → Podman has no built-in multi-host orchestrator.**
  For multi-server orchestration, people typically use one of these patterns:

  1. **Kubernetes** (k3s, kubeadm, etc.). Podman can *generate* and *play* Kubernetes YAML (`podman generate kube`, `podman play kube`) so you can lift a local Podman workload into a real multi-node orchestrator. ([Podman Documentation][2])
  2. **systemd + Quadlet (+ Ansible)** for “gitops-y” host management (great for many single-node deployments). You define `.container`/`.kube` unit files, enable **auto-update**, and distribute them with Ansible. This gives you reliable boot-time start, health-restarts, and hands-off updates across lots of machines—without running K8s. ([Red Hat][3])
  3. **Podman Desktop** can list/switch between multiple remote Podman connections (nice for ad-hoc ops, not orchestration). ([podman-desktop.io][4])

---

### Minimal setup to manage several servers with Podman

1. **On each server (rootless example):**

```bash
# as the target user on each host
systemctl --user enable --now podman.socket
loginctl enable-linger $USER   # keep user services running after logout (optional but handy)
```

2. **From your admin machine:**

```bash
# add connections (use ed25519 keys over SSH)
podman system connection add prod1 ssh://user@prod1.example.com/run/podman/podman.sock
podman system connection add prod2 ssh://user@prod2.example.com/run/podman/podman.sock
podman system connection ls
podman --connection prod1 ps
```

(SSH-based remote usage and key guidance are covered in Podman’s remote tutorial.) ([GitHub][5])

3. **If you want simple “fleet-like” rollouts without K8s:**

   * Write Quadlet units (e.g., `/etc/containers/systemd/myapp.container`), enable them with `systemctl enable --now myapp.service`, and turn on image **auto-updates**.
   * Use Ansible to copy/update those unit files and run `systemctl daemon-reload && systemctl restart myapp` across hosts.
     Quadlet + auto-update is the sweet spot for many small/medium fleets. ([Red Hat][3])

4. **If you need real multi-host scheduling/HA:** move to **Kubernetes** (k3s is lightweight). Use `podman generate kube` to export manifests from your working Podman setup, then apply them to the cluster. ([Podman Documentation][2])

---

### Quick FAQ

* **Is there a `podman context` command?**
  Historically no; the Podman way is `podman system connection` (contexts by another name). ([Podman Documentation][1])

* **Can I manage multiple hosts from a GUI?**
  Yes—**Podman Desktop** supports multiple remote connections and basic lifecycle ops. ([podman-desktop.io][4])

* **Compose support?**
  **Podman Compose** works for single-host stacks; it’s not a multi-host orchestration tool. (For multi-host, see K8s or Quadlet+Ansible.) ([Podman Documentation][2])

If you tell me how many servers you have and whether you prefer K8s or a “systemd+Ansible” approach, I’ll sketch a concrete setup (inventory, playbooks, and sample Quadlets) tailored to your environment.

[1]: https://docs.podman.io/en/latest/markdown/podman-system-connection.1.html "podman-system-connection — Podman  documentation"
[2]: https://docs.podman.io/en/latest/Commands.html?utm_source=chatgpt.com "Commands — Podman documentation"
[3]: https://www.redhat.com/en/blog/quadlet-podman?utm_source=chatgpt.com "Make systemd better for Podman with Quadlet - Enable Sysadmin"
[4]: https://podman-desktop.io/docs/podman/podman-remote?utm_source=chatgpt.com "Remote access - Podman Desktop"
[5]: https://github.com/containers/podman/blob/main/docs/tutorials/remote_client.md?utm_source=chatgpt.com "podman/docs/tutorials/remote_client.md at main - GitHub"

---

Love that plan. Here’s a clean way to do it on Hetzner: a single “prod terminal” (jump/ops host) that holds your keys and **drives all the other servers via Podman remote**, with a tiny script that discovers hosts from your Hetzner project and wires up the Podman connections automatically.

---

# Architecture (quick)

* **Ops host (your “production terminal”)**
  Small Hetzner VM in the same private network as your app servers. Lock SSH to your IPs, store read-only Git deploy repo, Ansible (optional), and your Podman remotes.
  Podman itself runs on the *targets*; the ops host only talks to their **Podman API sockets over SSH**. ([Podman Documentation][1])

* **Targets (app servers)**
  Each server runs Podman; enable the **user or root Podman API socket** so it’s reachable via SSH. You’ll point `podman system connection` at each target. ([Podman Documentation][2])

* **Discovery**
  Use Hetzner’s **`hcloud` CLI** (or API) to list servers in a project (optionally by label, network, or name prefix). That gives you IPs to auto-register Podman connections. ([GitHub][3])

* **Orchestration choices**

  * **Lightweight “fleet”**: systemd **Quadlet** units + optional **Podman auto-update** for hands-off rollouts. Great for many single-node services. ([Oracle Docs][4])
  * **Full scheduler/HA**: move to **Kubernetes** later; Podman can export K8s YAML (`podman generate kube`) if/when you make that jump. ([Podman Documentation][1])

---

# One-time setup

**On each app server (rootless example):**

```bash
# as the deploy user (e.g., app)
systemctl --user enable --now podman.socket
loginctl enable-linger $USER   # keep user systemd running after logout (optional)
```

(That exposes the user’s Podman REST API via systemd socket so remote commands work over SSH.) ([GitHub][5])

**On the ops host:**

```bash
# 1) Install Podman and hcloud CLI
#    (hcloud uses per-project "contexts" with your API token)
hcloud context create prod
hcloud context use prod
hcloud server list
```

(`hcloud` contexts make it easy to target the right project and list servers programmatically.) ([GitHub][3])

---

# Auto-register Podman connections from your Hetzner project

Save this on the ops host as `wire-podman-connections.sh` and run it any time you add/remove servers.

```bash
#!/usr/bin/env bash
set -euo pipefail

HCLOUD_CTX="${HCLOUD_CTX:-prod}"     # hcloud context to use
SSH_USER="${SSH_USER:-app}"          # user on target hosts that runs podman
LABEL_SELECTOR="${LABEL_SELECTOR:-role=app}"  # optional: only pick labeled servers
SOCK_PATH="${SOCK_PATH:-/run/user/1000/podman/podman.sock}"  # rootless default (uid 1000)
IDENTITY_FILE="${IDENTITY_FILE:-$HOME/.ssh/id_ed25519}"      # your key

# ensure we’re on the right project
hcloud context use "$HCLOUD_CTX" >/dev/null

# fetch servers (JSON) filtered by label if set
if [[ -n "$LABEL_SELECTOR" ]]; then
  srv_json=$(hcloud server list -o json | jq -r --arg sel "$LABEL_SELECTOR" \
    '.[] | select(.labels[$sel | split("=")[0]] == ($sel | split("=")[1]))')
else
  srv_json=$(hcloud server list -o json)
fi

# extract name and ipv4
echo "$srv_json" | jq -r '.name + " " + .public_net.ipv4.ip' | while read -r NAME IP; do
  CONN_NAME="${NAME}"
  DEST="ssh://${SSH_USER}@${IP}${SOCK_PATH}"
  echo "Configuring podman connection: ${CONN_NAME} -> ${DEST}"
  podman system connection remove "${CONN_NAME}" >/dev/null 2>&1 || true
  podman system connection add --identity "${IDENTITY_FILE}" "${CONN_NAME}" "${DEST}"
done

echo "Current connections:"
podman system connection ls
```

* It uses **`hcloud server list -o json`** to discover hosts (optional label filter, e.g., `role=app`).
* It creates Podman connections that point to `ssh://user@IP/run/.../podman.sock`.
* Swap `SOCK_PATH` to `/run/podman/podman.sock` if you prefer **rootful** Podman.
* Your ops host can now do `podman --connection server-a ps`, etc. ([GitHub][3])

> Docs: `podman system connection add` supports SSH destinations and identity files; Podman remote is an SSH-tunneled REST client. ([Podman Documentation][2])

---

# Deploying apps the simple, robust way (no Kubernetes)

Use **Quadlet** files with **auto-update** to get safe restarts and easy fleet rollouts:

**Example** `/etc/containers/systemd/myapp.container` on each target:

```ini
[Unit]
Description=MyApp container

[Container]
Image=ghcr.io/acme/myapp:stable
ContainerName=myapp
PublishPort=8080:8080
Environment=ENV=prod
# optional healthcheck if your image defines one:
# HealthCmd=CMD-SHELL curl -f http://127.0.0.1:8080/health || exit 1
# HealthInterval=30s

# Auto-update label tells podman-auto-update to manage this unit
Label=io.containers.autoupdate=image

[Install]
WantedBy=default.target
```

Enable + start:

```bash
systemctl --user daemon-reload
systemctl --user enable --now myapp.service
```

Then on each host (via Ansible or ad-hoc), run periodic:

```bash
podman auto-update
```

This pulls new images and restarts the unit if the image changed. You can cron/timer it or trigger via Ansible across all hosts. ([Podman Documentation][6])

---

# Security & hygiene checklist

* Put the ops host in the **same Hetzner private network** as app servers; restrict **public SSH** via Hetzner firewalls/security groups.
* Use **ed25519** SSH keys; keep `podman.socket` running only for the deploy user; prefer **rootless** where possible. ([GitHub][5])
* Tag servers with labels like `role=app`, `env=prod` so your script discovers exactly what you want. (Supported by Hetzner API/CLI.) ([docs.hetzner.cloud][7])

---

# Daily ops from the terminal

```bash
# list all connections the script created
podman system connection ls

# run commands on a single server
podman --connection app-01 ps
podman --connection app-02 logs myapp

# fan out with a for-loop
for c in $(podman system connection ls --format '{{.Name}}'); do
  echo "==== $c"; podman --connection "$c" ps --format '{{.Names}}  {{.Image}}  {{.Status}}'
done
```

(If you prefer, Podman Desktop can also show/switch among these remotes.) ([podman-desktop.io][8])

---

If you want, I can adapt the script to:

* select servers by **Hetzner network** or **name prefix**,
* point to **rootful** sockets,
* or output an **Ansible inventory** straight from `hcloud` JSON.

[1]: https://docs.podman.io/en/latest/markdown/podman-remote.1.html?utm_source=chatgpt.com "podman-remote — Podman documentation"
[2]: https://docs.podman.io/en/latest/markdown/podman-system-connection-add.1.html?utm_source=chatgpt.com "podman-system-connection-add — Podman documentation"
[3]: https://github.com/hetznercloud/cli/blob/main/docs/tutorials/setup-hcloud-cli.md?utm_source=chatgpt.com "cli/docs/tutorials/setup-hcloud-cli.md at main - GitHub"
[4]: https://docs.oracle.com/en/learn/ol-podman-quadlet/index.html?utm_source=chatgpt.com "Run Podman Containers Under Systemd with Quadlet - docs.oracle.com"
[5]: https://github.com/containers/podman/blob/main/docs/tutorials/remote_client.md?utm_source=chatgpt.com "podman/docs/tutorials/remote_client.md at main - GitHub"
[6]: https://docs.podman.io/en/v5.3.2/markdown/podman-auto-update.1.html?utm_source=chatgpt.com "podman-auto-update — Podman documentation - docs.podman.io"
[7]: https://docs.hetzner.cloud/reference/cloud?utm_source=chatgpt.com "Hetzner Cloud API"
[8]: https://podman-desktop.io/docs/podman/podman-remote?utm_source=chatgpt.com "Remote access - Podman Desktop"

---

Great question. Kubernetes can be either “way too much” or “exactly right,” depending on what you want to automate. Here’s a crisp way to decide, plus what a lean Hetzner setup would look like if you go for it.

# When K8s is probably overkill

* You have **≤5 servers**, a handful of services, and “deploy → restart” is enough.
* You don’t need cluster-wide **auto-scaling**, **self-healing**, or **zero-downtime** rollouts.
* You’re happy with **systemd (Quadlet) + Podman auto-update** and maybe Ansible to fan out changes.
* Your team is **small** and you’d rather spend time shipping features than operating a control plane.

# When K8s is a good fit

* You want **rolling/blue-green** deploys, health-based restarts, and easy canaries.
* You need **HA** (control plane and services), or plan to scale to **dozens of nodes**.
* You want **declarative GitOps** (Argo CD/Flux), per-service **quotas/limits**, and **namespaces** for multi-tenant isolation.
* You need built-in **Service/Ingress/LoadBalancer** abstractions, **cert-manager** TLS, and **Horizontal Pod Autoscaling**.
* You’re okay owning some **operational complexity** (upgrades, backups, monitoring).

---

# What a lean K8s-on-Hetzner stack looks like

### Minimal cluster shape (k3s)

* **3× small control-plane nodes** (for HA)
* **2–N worker nodes** (start with 2–3)
* **Private Hetzner network** for east-west traffic; firewall off public access except what you expose via Ingress/LB.

### Core components

* **Distro:** `k3s` (lightweight, batteries included).
* **CNI:** k3s default (flannel) is fine; you can swap to **Cilium** later if you want extras.
* **Hetzner integrations:**

  * **hcloud-cloud-controller-manager (CCM)** → creates LoadBalancers, sets node addresses.
  * **hcloud-CSI driver** → PersistentVolumes backed by Hetzner volumes/snapshots.
* **Ingress:** k3s ships with **Traefik** (keep it to start).
* **TLS:** **cert-manager** + HTTP-01 challenge via Ingress.
* **DNS (optional):** **ExternalDNS** with Hetzner DNS if you use their nameservers.
* **GitOps (optional but nice):** **Argo CD** or **Flux** for declarative deploys.
* **Observability:** **kube-prometheus-stack** (Prometheus+Alertmanager+Grafana), **Loki** for logs.
* **Backups:** **Velero** to Hetzner Object Storage (S3-compatible).

### Bring-up (high level)

1. **Provision VMs** (Ubuntu/Debian), attach to a **private network**.
2. **Install k3s on control-plane #1**:

   ```bash
   curl -sfL https://get.k3s.io | sh -s - server \
     --disable=servicelb \
     --write-kubeconfig-mode=644
   # Grab the node token for joining others:
   sudo cat /var/lib/rancher/k3s/server/node-token
   ```
3. **Join control-planes/agents** using that token (`--server https://<cp1-private-ip>:6443`).
4. **Install Hetzner CCM & CSI** with your Hetzner API token as a Kubernetes secret; apply their Helm charts/manifests.
5. (Optional) **Argo CD/Flux**, **cert-manager**, **ExternalDNS**, **kube-prometheus-stack** via Helm.
6. **Ingress + TLS**: point your domain to the Hetzner **LoadBalancer** that the CCM creates for your Ingress.

### Deploying an app (example)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector: { matchLabels: { app: myapp } }
  template:
    metadata: { labels: { app: myapp } }
    spec:
      containers:
      - name: myapp
        image: ghcr.io/acme/myapp:stable
        ports: [{containerPort: 8080}]
        readinessProbe:
          httpGet: { path: /health, port: 8080 }
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  type: ClusterIP
  selector: { app: myapp }
  ports: [{ port: 80, targetPort: 8080 }]
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
  - hosts: [myapp.example.com]
    secretName: myapp-tls
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service: { name: myapp, port: { number: 80 } }
```

* Scale via `kubectl scale deployment myapp --replicas=5`.
* Rolling updates happen automatically on image changes (or use GitOps).

### Ops you get “for free”

* **Self-healing:** pods rescheduled on node failures.
* **Rolling deploys:** zero-downtime updates with health checks.
* **Horizontal autoscaling:** react to CPU/metrics.
* **Consistent secrets/config:** `Secret`/`ConfigMap`, sealed/externals if needed.
* **Unified logging/metrics:** easy cluster-wide visibility.

---

# Migration path from your current Podman plan

* Keep developing locally or on a staging node with **Podman**.
* Use `podman generate kube` to spit out initial Kubernetes YAML from a working container/pod, then refine it (probes, resources, Ingress).
* Start with **one** namespace and one app → get CI/CD in place → then split services as you gain confidence.

---

# Quick decision checklist

Say **“K8s now”** if you check most of these:

* You want HA and rolling updates across **many servers**.
* You expect **service count** or **team size** to grow.
* You want **GitOps** and standardized deploys.

Say **“Podman + Quadlet + Ansible (for now)”** if you check these:

* Few servers, simple rollouts are fine.
* Minimal infra ops bandwidth.
* You’re okay doing updates via `podman auto-update` + restart windows.

---

If you want, I can sketch either:

* a **k3s on Hetzner** bootstrap (exact commands, Helm charts, and a minimal GitOps repo layout), or
* a **Podman Quadlet + Ansible** repo (inventories, roles, sample units).
  Which path are you leaning toward?
