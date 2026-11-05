<div align="center">

# Homelab k3s

**A hybrid ARM + x86 Kubernetes homelab, managed with GitOps.**

[![Validate](https://github.com/EA-etn/homelab-k3s/actions/workflows/validate.yml/badge.svg)](https://github.com/EA-etn/homelab-k3s/actions/workflows/validate.yml)
![k3s](https://img.shields.io/badge/k3s-v1.36-FFC61C?logo=k3s&logoColor=black)
![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo&logoColor=white)
![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi%204-arm64-A22846?logo=raspberrypi&logoColor=white)

**English** · [Español](README.es.md)

</div>

## What this is

The **platform** side of my lab: a k3s cluster on a Raspberry Pi 4 (arm64) and a laptop (amd64),
where **Git is the single source of truth**. ArgoCD watches this repository and keeps the
cluster in sync with it.

Applications are built elsewhere. [DevSecOps Pipeline](https://github.com/EA-etn/devsecops-pipeline)
tests, scans, signs and publishes `demo-api` as a multi-arch image; this repo decides **what runs
on the cluster**.

```
devsecops-pipeline ──(signed image + chart)──┐
                                             ▼
homelab-k3s ──(apps/)──► ArgoCD ──► k3s: Raspberry Pi 4 (arm64) + laptop (amd64)
```

## Repository layout

| Path | Purpose |
|---|---|
| `bootstrap/join-worker.sh` | Joins a machine to the cluster as a k3s agent (same version as the server) |
| `bootstrap/root-app.yaml` | App of Apps: the only Application applied by hand |
| `apps/` | One ArgoCD Application per workload. Add a file here to deploy something |
| `docs/inventory.md` | Hardware, network and installed software |

## Getting started

```bash
# 1. Join the laptop as a worker (run on the laptop; the token comes from the Pi)
sudo K3S_TOKEN='<token>' ./bootstrap/join-worker.sh

# 2. Hand the cluster over to Git
kubectl apply -f bootstrap/root-app.yaml

# 3. Watch ArgoCD create everything in apps/
kubectl -n argocd get applications
```

## Roadmap

- [x] k3s control plane on a Raspberry Pi 4 booting from SSD
- [x] ArgoCD and OpenBao (secrets) installed
- [x] Laptop joined as an amd64 worker
- [x] App of Apps: the cluster managed from this repo
- [x] `demo-api` deployed across both nodes (one replica per architecture)
- [ ] Observability: Prometheus and Grafana
- [ ] Secrets from OpenBao managed as code
- [ ] Clean up legacy test workloads

## License

[MIT](LICENSE)
