#!/usr/bin/env bash
set -euo pipefail

# Install a systemd TCP forwarder from the EC2 host to Minikube's NodePort.
# Override these defaults when invoking the installer, for example:
#   sudo LISTEN_PORT=30080 NODE_PORT=30080 ./deploy/install-minikube-forwarder.sh
RUN_AS_USER="${RUN_AS_USER:-ubuntu}"
LISTEN_PORT="${LISTEN_PORT:-80}"
NODE_PORT="${NODE_PORT:-30080}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
SERVICE_NAME="web-go-uoc-forward"
SCRIPT_PATH="/usr/local/sbin/${SERVICE_NAME}"
UNIT_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
DROPIN_DIR="/etc/systemd/system/${SERVICE_NAME}.service.d"
DROPIN_PATH="${DROPIN_DIR}/port-capability.conf"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this installer with sudo: sudo $0" >&2
  exit 1
fi

for port in "${LISTEN_PORT}" "${NODE_PORT}"; do
  if [[ ! "${port}" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
    echo "Invalid TCP port: ${port}" >&2
    exit 1
  fi
done

if ! id "${RUN_AS_USER}" >/dev/null 2>&1; then
  echo "User '${RUN_AS_USER}' does not exist. Set RUN_AS_USER to the Minikube owner." >&2
  exit 1
fi

MINIKUBE_BIN="$(command -v minikube || true)"
if [[ -z "${MINIKUBE_BIN}" ]]; then
  echo "minikube was not found in PATH; install it before this forwarder." >&2
  exit 1
fi

if ! command -v socat >/dev/null 2>&1; then
  apt-get update
  apt-get install -y socat
fi

USER_HOME="$(getent passwd "${RUN_AS_USER}" | cut -d: -f6)"
if [[ -z "${USER_HOME}" ]]; then
  echo "Could not find the home directory for '${RUN_AS_USER}'." >&2
  exit 1
fi

install -d -o root -g root -m 0755 "$(dirname "${SCRIPT_PATH}")"
cat >"${SCRIPT_PATH}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export HOME='${USER_HOME}'
export MINIKUBE_HOME='${USER_HOME}/.minikube'
export KUBECONFIG='${USER_HOME}/.kube/config'
export PATH='/usr/local/bin:/usr/bin:/bin'

'${MINIKUBE_BIN}' -p '${MINIKUBE_PROFILE}' start
minikube_ip=\$('${MINIKUBE_BIN}' -p '${MINIKUBE_PROFILE}' ip)
exec /usr/bin/socat TCP-LISTEN:${LISTEN_PORT},bind=0.0.0.0,reuseaddr,fork "TCP:\${minikube_ip}:${NODE_PORT}"
EOF
chmod 0755 "${SCRIPT_PATH}"

cat >"${UNIT_PATH}" <<EOF
[Unit]
Description=Forward EC2 port ${LISTEN_PORT} to Minikube NodePort ${NODE_PORT}
After=network-online.target docker.service
Wants=network-online.target docker.service

[Service]
Type=simple
User=${RUN_AS_USER}
Group=${RUN_AS_USER}
Environment=HOME=${USER_HOME}
Environment=MINIKUBE_HOME=${USER_HOME}/.minikube
Environment=KUBECONFIG=${USER_HOME}/.kube/config
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=${SCRIPT_PATH}
Restart=always
RestartSec=5
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

if (( LISTEN_PORT < 1024 )); then
  install -d -o root -g root -m 0755 "${DROPIN_DIR}"
  cat >"${DROPIN_PATH}" <<'EOF'
[Service]
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
EOF
else
  rm -f "${DROPIN_PATH}"
fi

systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}.service"
systemctl restart "${SERVICE_NAME}.service"

echo "Installed ${SERVICE_NAME}. Check it with:"
echo "  sudo systemctl status ${SERVICE_NAME} --no-pager"
echo "  sudo journalctl -u ${SERVICE_NAME} -n 30 --no-pager"
echo "  sudo ss -lntp | grep ':${LISTEN_PORT}'"
echo "  curl -I http://127.0.0.1:${LISTEN_PORT}/"
