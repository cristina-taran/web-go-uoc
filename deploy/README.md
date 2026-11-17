# EC2 and Minikube deployment

## Workflow: test → PR → main

The intended release path is `test` → pull request → `main`:

1. Push changes to the `test` branch. Jenkins builds the Docker image and deploys it to the isolated Kubernetes namespace `web-go-uoc-test` (NodePort `30081`, one replica).
2. Validate the test deployment, then open a pull request from `test` to `main`.
3. After the pull request is reviewed and merged, Jenkins builds the `main` branch and deploys production to namespace `web-go-uoc` (NodePort `30080`, two replicas).

Protect `main` in GitHub so production changes arrive through pull requests. Other branches can build the image but do not deploy. The public EC2 port `80` forwards to production NodePort `30080`; the test NodePort is not exposed by that public forwarder.

Configure Jenkins as a **Multibranch Pipeline** for this GitHub repository and set the script path to `Jenkinsfile`. GitHub Branch Source and a GitHub webhook/scan trigger are required so Jenkins discovers branches and starts builds when they change.

## Install or update the EC2 forwarding service

Run on the EC2 host after Minikube and the Kubernetes application are installed:

```bash
sudo bash deploy/install-minikube-forwarder.sh
```

The installer ensures `socat` is present and enables a systemd service that starts Minikube and forwards EC2 port `80` to Minikube NodePort `30080`.

## Install or update Jenkins' Minikube deploy helper

After checking out the repository on EC2, install the version-controlled helper used by the Jenkinsfile:

```bash
sudo install -o root -g root -m 0755 \
  deploy/web-go-uoc-deploy.sh /usr/local/sbin/web-go-uoc-deploy
```

The EC2 sudoers rule allows Jenkins to run only this helper as `ubuntu`. The helper accepts exactly five arguments: commit tag, Jenkins workspace, namespace, NodePort, and replica count. It permits only the `test` and `main` deployment targets above.

Inspect the systemd forwarding service with:

```bash
sudo systemctl status web-go-uoc-forward --no-pager
sudo journalctl -u web-go-uoc-forward -n 30 --no-pager
```
