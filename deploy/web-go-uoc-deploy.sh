#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo 'Usage: web-go-uoc-deploy IMAGE_TAG WORKSPACE NAMESPACE NODE_PORT REPLICAS' >&2
  exit 2
fi

tag="$1"
workspace="$2"
namespace="$3"
node_port="$4"
replicas="$5"

if [[ ! "${tag}" =~ ^[a-f0-9]{7,40}$ ]]; then
  echo 'ERROR: invalid image tag.' >&2
  exit 2
fi

case "${workspace}" in
  /var/lib/jenkins/workspace/web-go-uoc|/var/lib/jenkins/workspace/web-go-uoc_*) ;;
  *) echo 'ERROR: deployment workspace is not an allowed web-go-uoc branch workspace.' >&2; exit 2 ;;
esac

case "${namespace}:${node_port}:${replicas}" in
  web-go-uoc-test:30081:1|web-go-uoc:30080:2) ;;
  *) echo 'ERROR: invalid branch deployment target.' >&2; exit 2 ;;
esac

for manifest in namespace.yaml deployment.yaml service.yaml; do
  if [[ ! -f "${workspace}/k8s/${manifest}" ]]; then
    echo "ERROR: missing Kubernetes manifest: ${manifest}" >&2
    exit 2
  fi
done

export HOME=/home/ubuntu
export MINIKUBE_HOME=/home/ubuntu/.minikube
export KUBECONFIG=/home/ubuntu/.kube/config
export PATH=/usr/local/bin:/usr/bin:/bin

if ! /usr/local/bin/minikube -p minikube status --format='{{.Host}}' 2>/dev/null | /usr/bin/grep -qx 'Running'; then
  /usr/local/bin/minikube -p minikube start
fi

/usr/local/bin/minikube -p minikube image load "web-go-uoc:${tag}"
/usr/bin/sed "s|__NAMESPACE__|${namespace}|g" "${workspace}/k8s/namespace.yaml" | /usr/bin/kubectl apply -f -
/usr/bin/sed \
  -e "s|__NAMESPACE__|${namespace}|g" \
  -e "s|__IMAGE_TAG__|${tag}|g" \
  -e "s|__REPLICAS__|${replicas}|g" \
  "${workspace}/k8s/deployment.yaml" | /usr/bin/kubectl apply -f -
/usr/bin/sed \
  -e "s|__NAMESPACE__|${namespace}|g" \
  -e "s|__NODE_PORT__|${node_port}|g" \
  "${workspace}/k8s/service.yaml" | /usr/bin/kubectl apply -f -
/usr/bin/kubectl rollout status "deployment/web-go-uoc" -n "${namespace}" --timeout=180s
