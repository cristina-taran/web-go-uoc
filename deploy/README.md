# EC2 and Minikube deployment

## Multibranch deployment

Configure Jenkins as a **Multibranch Pipeline** for this GitHub repository and
set the script path to `Jenkinsfile`. The pipeline checks out each branch once,
builds an image tagged with its commit, and deploys only the `test` and `main`
branches:

| Branch | Kubernetes namespace | NodePort | Replicas | Purpose |
| --- | --- | ---: | ---: | --- |
| `test` | `web-go-uoc-test` | `30081` | 1 | Isolated test environment |
| `main` | `web-go-uoc` | `30080` | 2 | Production; EC2 port 80 forwards here |

Other branches run the image build but do not deploy. A Multibranch Pipeline
needs the GitHub Branch Source plugin and a GitHub push webhook/scan trigger so
Jenkins discovers new branches and starts builds when they change.

The test NodePort is internal to the EC2/Minikube setup; the existing public
forwarder exposes production on `http://<EC2-public-IP>/` only.

## Install or update the EC2 forwarding service

Run on the EC2 host after Minikube and the Kubernetes application are installed:

```bash
sudo bash deploy/install-minikube-forwarder.sh
```

The installer ensures `socat` is present and enables a systemd service that
starts Minikube and forwards EC2 port `80` to Minikube NodePort `30080`.

## Install or update Jenkins' Minikube deploy helper

After checking out the repository on EC2, install the version-controlled helper
used by the Jenkinsfile:

```bash
sudo install -o root -g root -m 0755 \
  deploy/web-go-uoc-deploy.sh /usr/local/sbin/web-go-uoc-deploy
```

The EC2 sudoers rule allows Jenkins to run only this helper as `ubuntu`. The
helper accepts the commit tag, Jenkins workspace, namespace, NodePort, and
replica count. It permits only the two branch targets listed above.

Inspect the systemd forwarding service with:

```bash
sudo systemctl status web-go-uoc-forward --no-pager
sudo journalctl -u web-go-uoc-forward -n 30 --no-pager
```
