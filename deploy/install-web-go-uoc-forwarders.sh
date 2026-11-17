#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this setup with sudo: sudo bash $0" >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "${SCRIPT_DIR}/install-minikube-forwarder.sh" 80 30080
bash "${SCRIPT_DIR}/install-minikube-forwarder.sh" 8081 30081
