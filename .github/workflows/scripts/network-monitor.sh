#!/bin/bash
# Network Monitor for Airgap Testing
# Detects and logs external network connections during airgap deployment testing

set -euo pipefail

LOG_FILE="${LOG_FILE:-/tmp/network-activity.log}"
ALERT_FILE="${ALERT_FILE:-/tmp/network-alerts.log}"
MONITOR_INTERVAL="${MONITOR_INTERVAL:-5}"

# Allowed destinations (local services)
ALLOWED_HOSTS=(
  "127.0.0.1"
  "localhost"
  "host.k3d.internal"
  "0.0.0.0"
)

ALLOWED_PORTS=(
  "5000"   # k3d registry
  "5001"   # Hauler K3s registry
  "5002"   # Hauler ESS registry
  "8080"   # Hauler fileserver
  "8081"   # Hauler Helm fileserver
  "6443"   # K3s API
)

# Initialize logs
echo "Network Monitor Started: $(date)" | tee "$LOG_FILE"
echo "Monitoring for external connections..." | tee -a "$LOG_FILE"
echo "Allowed hosts: ${ALLOWED_HOSTS[*]}" | tee -a "$LOG_FILE"
echo "Allowed ports: ${ALLOWED_PORTS[*]}" | tee -a "$LOG_FILE"
echo "---" | tee -a "$LOG_FILE"

# Function to check if host/port is allowed
is_allowed() {
  local host="$1"
  local port="$2"
  
  # Check if host is in allowed list
  for allowed_host in "${ALLOWED_HOSTS[@]}"; do
    if [[ "$host" == *"$allowed_host"* ]]; then
      return 0
    fi
  done
  
  # Check if port is in allowed list
  for allowed_port in "${ALLOWED_PORTS[@]}"; do
    if [[ "$port" == "$allowed_port" ]]; then
      return 0
    fi
  done
  
  return 1
}

# Function to monitor network connections
monitor_connections() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  # Get established connections
  netstat -tunapo 2>/dev/null | grep ESTABLISHED | while read -r line; do
    # Extract destination host and port
    dest=$(echo "$line" | awk '{print $5}')
    host=$(echo "$dest" | cut -d':' -f1)
    port=$(echo "$dest" | cut -d':' -f2)
    
    # Skip if allowed
    if is_allowed "$host" "$port"; then
      continue
    fi
    
    # Log external connection
    echo "[$timestamp] EXTERNAL CONNECTION: $line" | tee -a "$LOG_FILE" >> "$ALERT_FILE"
  done
}

# Function to monitor DNS queries
monitor_dns() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  # Check for DNS queries (port 53)
  netstat -tunapo 2>/dev/null | grep ":53" | while read -r line; do
    dest=$(echo "$line" | awk '{print $5}')
    host=$(echo "$dest" | cut -d':' -f1)
    
    # Skip local DNS
    if [[ "$host" == "127.0.0.1" ]] || [[ "$host" == "127.0.0.53" ]]; then
      continue
    fi
    
    echo "[$timestamp] DNS QUERY: $line" | tee -a "$LOG_FILE" >> "$ALERT_FILE"
  done
}

# Function to check for HTTP(S) traffic
monitor_http() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  # Check for HTTP/HTTPS connections (ports 80, 443)
  netstat -tunapo 2>/dev/null | grep -E ":(80|443) .*ESTABLISHED" | while read -r line; do
    dest=$(echo "$line" | awk '{print $5}')
    host=$(echo "$dest" | cut -d':' -f1)
    port=$(echo "$dest" | cut -d':' -f2)
    
    # Skip if allowed
    if is_allowed "$host" "$port"; then
      continue
    fi
    
    echo "[$timestamp] HTTP/HTTPS CONNECTION: $line" | tee -a "$LOG_FILE" >> "$ALERT_FILE"
  done
}

# Function to check Docker pulls
monitor_docker_pulls() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  # Monitor Docker daemon logs for image pulls
  if command -v docker &> /dev/null; then
    # This is a simplified check - in production, you'd monitor Docker events
    docker events --since 10s --filter 'type=image' --filter 'event=pull' 2>/dev/null | \
      while read -r event; do
        echo "[$timestamp] DOCKER PULL EVENT: $event" | tee -a "$LOG_FILE" >> "$ALERT_FILE"
      done &
  fi
}

# Main monitoring loop
echo "Starting monitoring loop (Ctrl+C to stop)..."

trap 'echo "Monitor stopped at $(date)" | tee -a "$LOG_FILE"; exit 0' INT TERM

while true; do
  monitor_connections
  monitor_dns
  monitor_http
  
  # Sleep between checks
  sleep "$MONITOR_INTERVAL"
done
