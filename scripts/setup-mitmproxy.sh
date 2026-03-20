#!/usr/bin/env bash
set -euo pipefail

# Usage: setup-mitmproxy.sh [--dry-run] [--yes]
# Runs mitmdump once to generate the mitmproxy CA certificate (~/.mitmproxy/),
# then trusts it in the macOS System keychain.

DRY_RUN=0
ASSUME_YES=0
CERT_DIR="$HOME/.mitmproxy"
CA_CERT="$CERT_DIR/mitmproxy-ca-cert.pem"
WAIT_TIMEOUT=30
KEYCHAIN="/Library/Keychains/System.keychain"

while [[ ${1-} != "" ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --yes) ASSUME_YES=1 ;;
    -h|--help)
      sed -n '1,10p' "$0"
      exit 0
      ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
  shift
done

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: $*"
  else
    eval "$@"
  fi
}

echo "Setting up mitmproxy..."

if ! command -v mitmdump >/dev/null 2>&1; then
  echo "mitmdump not found; skipping mitmproxy setup."
  exit 0
fi

# Generate the CA cert if it doesn't already exist.
if [ -f "$CA_CERT" ]; then
  echo "mitmproxy CA cert already exists at $CA_CERT."
else
  echo "Starting mitmdump briefly to generate CA certificates..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: mitmdump (background, terminated after $CA_CERT appears)"
  else
    mitmdump >/dev/null 2>&1 &
    MITMDUMP_PID=$!
    elapsed=0
    while [ ! -f "$CA_CERT" ] && [ "$elapsed" -lt "$WAIT_TIMEOUT" ]; do
      sleep 1
      elapsed=$((elapsed + 1))
    done
    kill "$MITMDUMP_PID" 2>/dev/null || true
    wait "$MITMDUMP_PID" 2>/dev/null || true
    if [ ! -f "$CA_CERT" ]; then
      echo "Error: mitmproxy CA cert was not created after ${WAIT_TIMEOUT}s. Aborting."
      exit 1
    fi
    echo "mitmproxy CA cert generated."
  fi
fi

# Trust the cert in the System keychain if not already trusted.
if security find-certificate -c mitmproxy "$KEYCHAIN" >/dev/null 2>&1; then
  echo "mitmproxy CA cert already trusted in System keychain; skipping."
else
  echo "Trusting mitmproxy CA cert in System keychain..."
  run sudo security add-trusted-cert -d -p ssl -p basic -k "$KEYCHAIN" "$CA_CERT"
  echo "mitmproxy CA cert trusted."
fi
