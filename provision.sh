#!/usr/bin/env bash
# Installs Docker, kubectl, minikube, then deploys the iti_cicd manifests.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

REPO_URL="https://github.com/Gamal-Mohammad/iti_cicd.git"
USER_NAME="vagrant"
USER_HOME="/home/${USER_NAME}"
PROJECT_DIR="${USER_HOME}/iti_cicd"
LOCAL_PORT=8082

echo "==> Growing root filesystem to use the whole disk"
apt-get update -y
apt-get install -y cloud-guest-utils
growpart /dev/sda 1 || true
resize2fs /dev/sda1 || true

echo "==> Installing Docker, git, curl, conntrack"
apt-get install -y docker.io git curl conntrack
systemctl enable --now docker
usermod -aG docker "${USER_NAME}"

echo "==> Installing kubectl"
CURL="curl -fL --http1.1 --retry 8 --retry-delay 5 --retry-all-errors --connect-timeout 30"
KVER="$($CURL -s https://dl.k8s.io/release/stable.txt)"
$CURL -o /tmp/kubectl "https://dl.k8s.io/release/${KVER}/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl

echo "==> Installing minikube"
$CURL -o /tmp/minikube https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
install -m 0755 /tmp/minikube /usr/local/bin/minikube

echo "==> Cloning the project"
if [ ! -d "${PROJECT_DIR}" ]; then
  sudo -u "${USER_NAME}" git clone "${REPO_URL}" "${PROJECT_DIR}"
fi

echo "==> Starting the cluster and deploying (as ${USER_NAME})"
sudo -u "${USER_NAME}" -H bash <<EOF
set -euo pipefail
cd "${PROJECT_DIR}"

# 'sg docker' makes the new docker group active without re-login
sg docker -c "minikube start --driver=docker --memory=3072 --cpus=2"

kubectl apply -f app-secret.yml

kubectl apply -f vprodbdep.yml
kubectl apply -f db-CIP.yml

kubectl apply -f mcdep.yml
kubectl apply -f mc-CIP.yml

kubectl apply -f rmq-dep.yml
kubectl apply -f rmq-CIP-service.yml

kubectl apply -f vproappdep.yml
kubectl apply -f vproapp-service.yml

echo "Waiting for deployments to become ready (up to 10 min)..."
kubectl wait --for=condition=available deployment --all --timeout=600s || true
kubectl get pods
kubectl get svc
EOF

echo "==> Setting up a boot-time port-forward for the app on port ${LOCAL_PORT}"
APP_SVC="$(sudo -u ${USER_NAME} kubectl get svc -o name | grep -i vproapp | head -n1 | cut -d/ -f2 || true)"
APP_PORT="$(sudo -u ${USER_NAME} kubectl get svc "${APP_SVC}" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo 8080)"

if [ -n "${APP_SVC}" ]; then
cat > /etc/systemd/system/app-portforward.service <<UNIT
[Unit]
Description=kubectl port-forward for the app
After=network-online.target docker.service

[Service]
User=${USER_NAME}
ExecStartPre=/bin/bash -c 'minikube status >/dev/null 2>&1 || minikube start --driver=docker --memory=3072 --cpus=2'
ExecStart=/usr/local/bin/kubectl port-forward --address 0.0.0.0 svc/${APP_SVC} ${LOCAL_PORT}:${APP_PORT}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now app-portforward.service
  echo "==> Done. Open http://127.0.0.1:${LOCAL_PORT} on your PC."
else
  echo "!! Could not find a service with 'vproapp' in its name. Run: vagrant ssh, then kubectl get svc"
fi
