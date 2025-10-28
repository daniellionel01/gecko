# notes

## audio separation

- https://asteroid-team.github.io/

## observability

- https://www.selfping.com/
- https://healthchecks.io/

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

### security

https://github.com/healthyhost/audit-vps-script

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
