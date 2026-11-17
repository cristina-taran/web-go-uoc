# Minikube port forwarder on EC2

`install-minikube-forwarder.sh` installs `socat` if needed and registers a
systemd service that forwards an EC2 TCP port to a Minikube NodePort. The
service starts Minikube when it starts and is enabled at boot.

Run it on the EC2 host after Minikube and the application are installed:

```bash
sudo bash deploy/install-minikube-forwarder.sh
```

By default, it listens on EC2 port `80` and forwards to Minikube NodePort
`30080`. To use another listen port, NodePort, Minikube profile, or Linux user:

```bash
sudo env LISTEN_PORT=30080 NODE_PORT=30080 MINIKUBE_PROFILE=minikube RUN_AS_USER=ubuntu \
  bash deploy/install-minikube-forwarder.sh
```

Allow the chosen listen port in the EC2 Security Group, restricted to the
intended client IP ranges. Inspect and manage the service with:

```bash
sudo systemctl status web-go-uoc-forward --no-pager
sudo journalctl -u web-go-uoc-forward -n 30 --no-pager
sudo systemctl restart web-go-uoc-forward
```
