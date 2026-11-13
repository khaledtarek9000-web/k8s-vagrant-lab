# Kubernetes lab with Vagrant (iti_cicd)

One command builds a VirtualBox VM, installs Docker, kubectl and minikube, clones
[Gamal-Mohammad/iti_cicd](https://github.com/Gamal-Mohammad/iti_cicd) and deploys it to a single-node Kubernetes cluster.

## What you get

- Ubuntu 22.04 VM with a 30 GB disk, 6 GB RAM, 2 CPUs
- Docker, kubectl and minikube installed automatically
- The project's manifests applied in dependency order (secret, database, cache, RabbitMQ, app)
- The app reachable from your PC at `http://127.0.0.1:8090`

## Requirements (on your PC)

- [VirtualBox](https://www.virtualbox.org/)
- [Vagrant](https://www.vagrantup.com/) 2.3 or newer
- About 6 GB of free RAM and 30 GB of free disk
- Internet access

## Files

| File | Purpose |
|------|---------|
| `Vagrantfile` | VM definition: box, disk, RAM, CPUs, port forwarding |
| `provision.sh` | Installs the tools, clones the repo, deploys to Kubernetes |

## Usage

```bash
git clone <this-repository-url>
cd <this-repository-folder>
vagrant up
```

The first run takes about 15-25 minutes. When it finishes, open:

```
http://127.0.0.1:8090
```

## Useful commands

| Command | What it does |
|---------|--------------|
| `vagrant ssh` | Log into the VM |
| `vagrant halt` | Shut the VM down |
| `vagrant up` | Start it again |
| `vagrant provision` | Re-run the setup script |
| `vagrant destroy -f` | Delete the VM completely |

Inside the VM (`vagrant ssh`):

```bash
kubectl get pods          # pod status
kubectl get svc           # services
kubectl logs <pod-name>   # logs of a pod
```

## Deployment order

`provision.sh` applies the manifests in this order, so dependencies exist before the app starts:

1. `app-secret.yml`
2. `vprodbdep.yml`, `db-CIP.yml` (MySQL)
3. `mcdep.yml`, `mc-CIP.yml` (Memcached)
4. `rmq-dep.yml`, `rmq-CIP-service.yml` (RabbitMQ)
5. `vproappdep.yml`, `vproapp-service.yml` (application)

## Configuration

| Setting | Where | Default |
|---------|-------|---------|
| Host port on your PC | `Vagrantfile` (`host:`) | `8090` |
| VM memory | `Vagrantfile` (`vb.memory`) | `6144` MB |
| VM CPUs | `Vagrantfile` (`vb.cpus`) | `2` |
| Disk size | `Vagrantfile` (`config.vm.disk`) | `30GB` |
| minikube memory | `provision.sh` (`--memory`) | `3072` MB |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `forwarded port ... is already in use` | Change `host: 8090` in the `Vagrantfile` to a free port |
| `curl: (92) HTTP/2 stream ... PROTOCOL_ERROR` | Network hiccup. Run `vagrant provision` again, or try another network |
| Pod stuck in `Pending` | Not enough memory or disk. Run `kubectl describe pod <name>` |
| `ImagePullBackOff` | Check internet access inside the VM and the image name |
| `CrashLoopBackOff` | Run `kubectl logs <pod-name>` |
| Warning about a missing `vproapp` service at the end | Run `kubectl get svc` inside the VM and check the service name |
| App returns errors | Make sure the DB, cache and RabbitMQ pods are `Running`, then `kubectl rollout restart deployment <app-deployment>` |

## Clean up

```bash
vagrant destroy -f
```

## Credits

Application and manifests: [Gamal-Mohammad/iti_cicd](https://github.com/Gamal-Mohammad/iti_cicd).
