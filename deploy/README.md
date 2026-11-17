# EC2 and Minikube deployment

## Workflow: test → PR → main

The intended release path is `test` → pull request → `main`:

1. Push changes to `test`. Jenkins builds the image and deploys to namespace `web-go-uoc-test` (NodePort `30081`, one replica). Open test at `http://<EC2-public-IP>:8081/`.
2. Validate test, then open a pull request from `test` to `main`.
3. After review and merge, Jenkins builds `main` and deploys production to namespace `web-go-uoc` (NodePort `30080`, two replicas).

Protect `main` in GitHub so production changes arrive through pull requests. Other branches can build the image but do not deploy. Restrict EC2 Security Group ingress for TCP `8081` to the tester's public IP with a `/32` source. Production is forwarded through EC2 TCP `80`.

Configure Jenkins as a **Multibranch Pipeline** for this repository with script path `Jenkinsfile`. GitHub Branch Source and a GitHub webhook/scan trigger let Jenkins discover branches and start builds when they change.

## Generic EC2-to-Minikube forwarding

The installer is generic: pass the EC2 listen port and the Minikube NodePort. It creates a shared `minikube.service` to start the cluster once, plus one templated forwarding service per mapping.

```bash
sudo bash deploy/install-minikube-forwarder.sh 80 30080
sudo bash deploy/install-minikube-forwarder.sh 8081 30081
```

The corresponding instances are `minikube-nodeport-forward@80-30080.service` and `minikube-nodeport-forward@8081-30081.service`. Their forwarding processes run as the Minikube owner; the systemd unit grants the low-port bind capability needed by port `80`.

When migrating a host that still has the earlier app-specific forwarders, stop those units once before installing the generic instances:

```bash
sudo systemctl disable --now web-go-uoc-forward.service web-go-uoc-test-forward.service
```

Check the cluster and forwards with:

```bash
sudo systemctl status minikube.service --no-pager
sudo systemctl status minikube-nodeport-forward@80-30080.service --no-pager
sudo systemctl status minikube-nodeport-forward@8081-30081.service --no-pager
curl -fsS -o /dev/null -w 'HTTP %{http_code}\n' http://127.0.0.1/
curl -fsS -o /dev/null -w 'HTTP %{http_code}\n' http://127.0.0.1:8081/
```

## Jenkins Minikube deploy helper

After checking out the repository on EC2, install the version-controlled helper used by Jenkins:

```bash
sudo install -o root -g root -m 0755 \
  deploy/web-go-uoc-deploy.sh /usr/local/sbin/web-go-uoc-deploy
```

The EC2 sudoers rule allows Jenkins to run only this helper as `ubuntu`. It accepts exactly five arguments: commit tag, Jenkins workspace, namespace, NodePort, and replica count. It permits only the `test` and `main` deployment targets above.
