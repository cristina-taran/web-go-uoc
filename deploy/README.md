# EC2 and Minikube deployment

## Workflow: test → PR → main

The release path is `test` → pull request → `main`:

1. Push changes to `test`. Jenkins builds the image and deploys to namespace `web-go-uoc-test` (NodePort `30081`, one replica). Open test at `http://<EC2-public-IP>:8081/`.
2. Validate test, then open a pull request from `test` to `main`.
3. After review and merge, Jenkins builds `main` and deploys production to namespace `web-go-uoc` (NodePort `30080`, two replicas).

Restrict EC2 Security Group ingress for TCP `8081` to the tester's public IP with a `/32` source. Production is served on EC2 port `80`.

Configure Jenkins as a **Multibranch Pipeline** for this repository with script path `Jenkinsfile`. GitHub Branch Source and a GitHub webhook/scan trigger let Jenkins discover branches and start builds when they change.

## Minikube systemd services and port forwarding

Run the app-specific setup script once on EC2 after Minikube is installed:

```bash
sudo bash deploy/install-web-go-uoc-forwarders.sh
```

That wrapper calls the generic installer for EC2 `80` → Minikube NodePort `30080` and EC2 `8081` → NodePort `30081`. The generic installer installs `deploy/systemd/minikube.service`, `deploy/systemd/minikube-nodeport-forward@.service`, and the helper `deploy/minikube-nodeport-forward.sh` on EC2. It enables a shared `minikube.service` to start the cluster once and two instances of the forwarding template.

The Jenkins pipeline does **not** call the installer: Jenkins builds and deploys the application. The administrator runs this setup once; systemd starts Minikube and the port forwarders on later boots. Each forwarding unit calls `minikube-nodeport-forward.sh` with its port mapping.

The generic installer can also be run directly for another mapping:

```bash
sudo bash deploy/install-minikube-forwarder.sh LISTEN_PORT NODE_PORT
```

When migrating a host that still has the older app-specific units, stop them once before running the setup:

```bash
sudo systemctl disable --now web-go-uoc-forward.service web-go-uoc-test-forward.service
```

Inspect the installed units and check local responses with:

```bash
sudo systemctl status minikube.service --no-pager
sudo systemctl status minikube-nodeport-forward@80-30080.service --no-pager
sudo systemctl status minikube-nodeport-forward@8081-30081.service --no-pager
curl -fsS -o /dev/null -w 'HTTP %{http_code}\n' http://127.0.0.1/
curl -fsS -o /dev/null -w 'HTTP %{http_code}\n' http://127.0.0.1:8081/
```

## Jenkins Minikube deploy helper

The EC2 sudoers rule allows Jenkins to run only the version-controlled helper as `ubuntu`:

```bash
sudo install -o root -g root -m 0755 \
  deploy/web-go-uoc-deploy.sh /usr/local/sbin/web-go-uoc-deploy
```

It accepts exactly five arguments: commit tag, Jenkins workspace, namespace, NodePort, and replica count. It permits only the `test` and `main` deployment targets above.
