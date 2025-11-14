#!/usr/bin/env bash
# Hauler service helpers
# Start/stop hauler registry and fileserver and perform simple health checks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

start_hauler_registry() {
  local port=${1:-5002}
  local store_path=${2:-}
  local serve_path=${3:-}
  local log_file=${4:-/tmp/hauler-registry.log}
  local pid_file=${5:-/tmp/hauler-registry.pid}

  echo "Starting Hauler registry on :$port (store=$store_path)..."
  nohup hauler store serve registry --port "$port" --store "$store_path" >"$log_file" 2>&1 &
  echo $! > "$pid_file"

  # Wait for registry to respond on /v2/
  local retries=0
  while [ $retries -lt 30 ]; do
    if curl -sS "http://localhost:$port/v2/" >/dev/null 2>&1; then
      echo "Hauler registry listening on :$port"
      return 0
    fi
    retries=$((retries + 1))
    sleep 1
  done

  echo "Registry did not become healthy (see $log_file)"
  return 1
}

start_hauler_fileserver() {
  local port=${1:-8080}
  local store_path=${2:-}
  local serve_path=${3:-}
  local log_file=${4:-/tmp/hauler-fileserver.log}
  local pid_file=${5:-/tmp/hauler-fileserver.pid}
  local directory=${6:-$serve_path}

  echo "Starting Hauler fileserver on :$port (store=$store_path, dir=$directory)..."
  nohup hauler store serve fileserver --port "$port" --store "$store_path" --directory "$directory" >"$log_file" 2>&1 &
  echo $! > "$pid_file"

  # Wait for fileserver root to be reachable
  local retries=0
  while [ $retries -lt 30 ]; do
    if curl -sS "http://localhost:$port/" >/dev/null 2>&1; then
      echo "Hauler fileserver listening on :$port"
      return 0
    fi
    retries=$((retries + 1))
    sleep 1
  done

  echo "Fileserver did not become healthy (see $log_file)"
  return 1
}

stop_hauler_services() {
  echo "Stopping hauler services..."
  # Kill any hauler processes started by these scripts
  pkill -f "hauler store serve" || true
  # Remove pid files if present
  rm -f /tmp/hauler-*-registry.pid /tmp/hauler-*-fileserver.pid /tmp/*-registry.pid /tmp/*-fileserver.pid || true
}

export -f start_hauler_registry start_hauler_fileserver stop_hauler_services
#!/bin/bash
# Shared Hauler Functions for Airgap Testing
# Used by both local airgap tests and GitHub Actions workflows

# Helper function for logging that works with or without color print functions
log_info() {
  if type print_step &>/dev/null; then
    print_step "$1"
  else
    echo "▶ $1"
  fi
}

log_success() {
  if type print_success &>/dev/null; then
    print_success "$1"
  else
    echo "✅ $1"
  fi
}

log_error() {
  if type print_error &>/dev/null; then
    print_error "$1"
  else
    echo "❌ $1"
  fi
}

# Start Hauler registry service with retry logic
# Args: $1=port, $2=store_name, $3=store_path, $4=log_file, $5=pid_file
start_hauler_registry() {
  local port="$1"
  local store_name="$2"
  local store_path="$3"
  local log_file="$4"
  local pid_file="$5"
  
  log_info "Starting Hauler registry on port $port..."
  cd "$store_path" || return 1
  nohup hauler store serve registry --port "$port" --store "$store_name" > "$log_file" 2>&1 &
  echo $! > "$pid_file"
  
  # Wait for registry to be ready with retries
  local retries=0
  while [ $retries -lt 30 ]; do
    if curl -f -s "http://localhost:$port/v2/_catalog" > /dev/null 2>&1; then
      log_success "Hauler registry on port $port is running"
      return 0
    fi
    retries=$((retries + 1))
    sleep 1
  done
  
  log_error "Hauler registry on port $port failed to start after 30 seconds"
  echo "Last 50 lines of log:"
  tail -n 50 "$log_file"
  return 1
}

# Start Hauler fileserver with retry logic
# Args: $1=port, $2=store_name, $3=store_path, $4=log_file, $5=pid_file, $6=directory
start_hauler_fileserver() {
  local port="$1"
  local store_name="$2"
  local store_path="$3"
  local log_file="$4"
  local pid_file="$5"
  local directory="${6:-}"
  
  log_info "Starting Hauler fileserver on port $port..."
  cd "$store_path" || return 1
  
  # Create directory if specified
  if [ -n "$directory" ]; then
    mkdir -p "$directory"
    nohup hauler store serve fileserver --port "$port" --store "$store_name" --directory "$directory" > "$log_file" 2>&1 &
  else
    nohup hauler store serve fileserver --port "$port" --store "$store_name" > "$log_file" 2>&1 &
  fi
  
  echo $! > "$pid_file"
  
  # Wait for fileserver to be ready with retries
  local retries=0
  while [ $retries -lt 30 ]; do
    if curl -f -s "http://localhost:$port" > /dev/null 2>&1; then
      log_success "Hauler fileserver on port $port is running"
      return 0
    fi
    retries=$((retries + 1))
    sleep 1
  done
  
  log_error "Hauler fileserver on port $port failed to start after 30 seconds"
  echo "Last 50 lines of log:"
  tail -n 50 "$log_file"
  return 1
}

# Verify Hauler registry is accessible
# Args: $1=port
verify_hauler_registry() {
  local port="$1"
  
  if ! curl -f "http://localhost:$port/v2/_catalog" 2>&1; then
    log_error "Registry on port $port is not accessible"
    return 1
  fi
  log_success "Registry on port $port is accessible"
  return 0
}

# Verify Hauler fileserver is accessible
# Args: $1=port
verify_hauler_fileserver() {
  local port="$1"
  
  if ! curl -f "http://localhost:$port" 2>&1; then
    log_error "Fileserver on port $port is not accessible"
    return 1
  fi
  log_success "Fileserver on port $port is accessible"
  return 0
}

# Stop all Hauler services by killing processes
stop_hauler_services() {
  log_info "Stopping all Hauler services..."
  pkill -f "hauler store serve" || true
  sleep 2
}
