#!/usr/bin/env bash
set -euo pipefail

# Install one generic EC2-to-Minikube TCP forwarding instance.
LISTEN_PORT="${1:-}"
NODE_PORT="${2:-}"
RUN_AS_USER="${RUN_AS_USER:-ubuntu}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"

if [[ "${EUID}" -ne 0 || $# -ne 2 ]]; then
  echo "Usage: sudo $0 LISTEN_PORT NODE_PORT" >&2
  exit 2
fi

for port in "${LISTEN_PORT}" "${NODE_PORT}"; do
  if [[ ! "${port}" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
    echo "Invalid TCP port: ${port}" >&2
    exit 2
  fi
done

if [[ ! "${RUN_AS_USER}" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
  echo "Invalid Linux user: ${RUN_AS_USER}" >&2
  exit 2
fi
if [[ ! "${MINIKUBE_PROFILE}" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo 'Invalid Minikube profile.' >&2
  exit 2
fi
if ! id "${RUN_AS_USER}" >/dev/null 2>&1; then
  echo "User '${RUN_AS_USER}' does not exist." >&2
  exit 1
fi

MINIKUBE_BIN="$(command -v minikube || true)"
if [[ -z "${MINIKUBE_BIN}" ]]; then
  echo 'minikube was not found in PATH.' >&2
  exit 1
fi
if ! command -v socat >/dev/null 2>&1; then
  apt-get update
  apt-get install -y socat
fi

USER_HOME="$(getent passwd "${RUN_AS_USER}" | cut -d: -f6)"
if [[ -z "${USER_HOME}" || "${USER_HOME}" == *'|'* ]]; then
  echo "Could not safely determine the home directory for '${RUN_AS_USER}'." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SYSTEMD_DIR="${SCRIPT_DIR}/systemd"
for file in minikube.service minikube-nodeport-forward@.service; do
  if [[ ! -f "${SYSTEMD_DIR}/${file}" ]]; then
    echo "Missing systemd unit source: ${SYSTEMD_DIR}/${file}" >&2
    exit 1
  fi
done

FORWARDER_PATH=/usr/local/sbin/minikube-nodeport-forward
INSTANCE="${LISTEN_PORT}-${NODE_PORT}"

install -o root -g root -m 0755 "${SCRIPT_DIR}/minikube-nodeport-forward.sh" "${FORWARDER_PATH}"
sed \
  -e "s|@@RUN_AS_USER@@|${RUN_AS_USER}|g" \
  -e "s|@@USER_HOME@@|${USER_HOME}|g" \
  -e "s|@@MINIKUBE_BIN@@|${MINIKUBE_BIN}|g" \
  -e "s|@@MINIKUBE_PROFILE@@|${MINIKUBE_PROFILE}|g" \
  "${SYSTEMD_DIR}/minikube.service" | install -o root -g root -m 0644 /dev/stdin /etc/systemd/system/minikube.service
sed \
  -e "s|@@RUN_AS_USER@@|${RUN_AS_USER}|g" \
  -e "s|@@USER_HOME@@|${USER_HOME}|g" \
  -e "s|@@MINIKUBE_PROFILE@@|${MINIKUBE_PROFILE}|g" \
  "${SYSTEMD_DIR}/minikube-nodeport-forward@.service" | install -o root -g root -m 0644 /dev/stdin /etc/systemd/system/minikube-nodeport-forward@.service

systemctl daemon-reload
systemctl enable --now minikube.service
systemctl enable --now "minikube-nodeport-forward@${INSTANCE}.service"
systemctl restart "minikube-nodeport-forward@${INSTANCE}.service"

echo "Enabled minikube-nodeport-forward@${INSTANCE}.service"
echo "EC2 TCP ${LISTEN_PORT} forwards to Minikube NodePort ${NODE_PORT}."
