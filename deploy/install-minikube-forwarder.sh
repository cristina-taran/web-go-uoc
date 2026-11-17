#!/usr/bin/env bash
set -euo pipefail

# Install a generic systemd instance forwarding an EC2 port to a Minikube
# NodePort. Invoke once per port mapping, for example: 80 30080 or 8081 30081.
LISTEN_PORT="${1:-}"
NODE_PORT="${2:-}"
RUN_AS_USER="${RUN_AS_USER:-ubuntu}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Usage: sudo $0 LISTEN_PORT NODE_PORT" >&2
  exit 1
fi

if [[ $# -ne 2 ]]; then
  echo "Usage: sudo $0 LISTEN_PORT NODE_PORT" >&2
  exit 2
fi

if [[ ! "${MINIKUBE_PROFILE}" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo 'Invalid Minikube profile name.' >&2
  exit 2
fi

for port in "${LISTEN_PORT}" "${NODE_PORT}"; do
  if [[ ! "${port}" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
    echo "Invalid TCP port: ${port}" >&2
    exit 2
  fi
done

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
if [[ -z "${USER_HOME}" ]]; then
  echo "Could not find the home directory for '${RUN_AS_USER}'." >&2
  exit 1
fi

FORWARDER_PATH=/usr/local/sbin/minikube-nodeport-forward
START_UNIT=/etc/systemd/system/minikube.service
FORWARD_UNIT=/etc/systemd/system/minikube-nodeport-forward@.service
INSTANCE="${LISTEN_PORT}-${NODE_PORT}"

cat >"${FORWARDER_PATH}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export PATH='/usr/local/bin:/usr/bin:/bin'

instance="\${1:-}"
if [[ "\${instance}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
  listen_port="\${BASH_REMATCH[1]}"
  node_port="\${BASH_REMATCH[2]}"
else
  echo 'Usage: minikube-nodeport-forward LISTEN_PORT-NODE_PORT' >&2
  exit 2
fi
for port in "\${listen_port}" "\${node_port}"; do
  if (( port < 1 || port > 65535 )); then
    echo "Invalid TCP port: \${port}" >&2
    exit 2
  fi
done

minikube_ip=\$('${MINIKUBE_BIN}' -p '${MINIKUBE_PROFILE}' ip)
exec /usr/bin/socat "TCP-LISTEN:\${listen_port},bind=0.0.0.0,reuseaddr,fork" "TCP:\${minikube_ip}:\${node_port}"
EOF
chmod 0755 "${FORWARDER_PATH}"

cat >"${START_UNIT}" <<EOF
[Unit]
Description=Minikube cluster
After=network-online.target docker.service
Wants=network-online.target docker.service

[Service]
Type=oneshot
User=${RUN_AS_USER}
Group=${RUN_AS_USER}
Environment=HOME=${USER_HOME}
Environment=MINIKUBE_HOME=${USER_HOME}/.minikube
Environment=KUBECONFIG=${USER_HOME}/.kube/config
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=${MINIKUBE_BIN} -p ${MINIKUBE_PROFILE} start
ExecStop=${MINIKUBE_BIN} -p ${MINIKUBE_PROFILE} stop
RemainAfterExit=yes
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

cat >"${FORWARD_UNIT}" <<EOF
[Unit]
Description=Forward EC2 TCP port %i to Minikube NodePort
Requires=minikube.service
After=minikube.service

[Service]
Type=simple
User=${RUN_AS_USER}
Group=${RUN_AS_USER}
Environment=HOME=${USER_HOME}
Environment=MINIKUBE_HOME=${USER_HOME}/.minikube
Environment=KUBECONFIG=${USER_HOME}/.kube/config
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=${FORWARDER_PATH} %i
Restart=always
RestartSec=5
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now minikube.service
systemctl enable --now "minikube-nodeport-forward@${INSTANCE}.service"
systemctl restart "minikube-nodeport-forward@${INSTANCE}.service"

echo "Enabled minikube-nodeport-forward@${INSTANCE}.service"
echo "EC2 TCP ${LISTEN_PORT} forwards to Minikube NodePort ${NODE_PORT}."
echo "Check with: sudo systemctl status minikube-nodeport-forward@${INSTANCE}.service --no-pager"
