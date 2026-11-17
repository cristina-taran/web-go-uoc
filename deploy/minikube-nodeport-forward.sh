#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/local/bin:/usr/bin:/bin

instance="${1:-}"
if [[ "${instance}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
  listen_port="${BASH_REMATCH[1]}"
  node_port="${BASH_REMATCH[2]}"
else
  echo 'Usage: minikube-nodeport-forward LISTEN_PORT-NODE_PORT' >&2
  exit 2
fi

for port in "${listen_port}" "${node_port}"; do
  if (( port < 1 || port > 65535 )); then
    echo "Invalid TCP port: ${port}" >&2
    exit 2
  fi
done

profile="${MINIKUBE_PROFILE:-minikube}"
minikube_bin="$(command -v minikube)"
minikube_ip="$("${minikube_bin}" -p "${profile}" ip)"
exec /usr/bin/socat "TCP-LISTEN:${listen_port},bind=0.0.0.0,reuseaddr,fork" "TCP:${minikube_ip}:${node_port}"
