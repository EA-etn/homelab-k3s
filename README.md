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

<img src="docs/diagrams/en/01-architecture.svg" alt="Architecture: GitHub repos feed ArgoCD, which syncs a k3s cluster on a Raspberry Pi and a PC; Prometheus, Grafana and Alertmanager run on the PC and alert to Telegram" width="100%">

<sub><a href="https://raw.githubusercontent.com/EA-etn/homelab-k3s/main/docs/diagrams/en/01-architecture.png">🔍 View full size</a></sub>

## Highlights

| | |
|---|---|
| ☸️ **Hybrid cluster** | k3s control plane on a Raspberry Pi 4 (arm64, boots from SSD) + laptop worker (amd64). The same multi-arch image runs on both |
| 🔄 **GitOps** | App of Apps: one manual `kubectl apply`, everything else comes from `apps/`. Self-heal and prune on |
| 📊 **Observability** | kube-prometheus-stack with dashboards as code, 30-day retention, synthetic traffic through the ingress |
| 🎯 **SLOs** | 99.5 % availability and 99 % of requests under 100 ms, error budget and multi-window burn-rate alerts ([docs/slo.md](docs/slo.md)) |
| 🚨 **Incident response** | Alerts to Telegram with a link to the [runbook](docs/runbooks/README.md) for each alert, inhibition and silences |
| 🧪 **Tested alerting** | `promtool` unit tests for every SLO alert and `amtool` checks for routing and the Telegram message, in CI |
| 🔐 **No secrets in Git** | Grafana password and Telegram token live in Secrets created by hand; the repo is public |

## Repository layout

| Path | Purpose |
|---|---|
| `bootstrap/join-worker.sh` | Joins a machine to the cluster as a k3s agent (same version as the server) |
| `bootstrap/root-app.yaml` | App of Apps: the only Application applied by hand |
| `apps/` | One ArgoCD Application per workload. Add a file here to deploy something |
| `platform/monitoring/` | Grafana dashboards, Prometheus alerts and SLOs as code |
| `tests/slo/` | Unit tests for the SLO rules and alerts (`promtool`, run in CI) |
| `tests/alertmanager/` | Alertmanager config, routing and Telegram message checks (`amtool`, run in CI) |
| `docs/inventory.md` | Hardware, network and installed software |
| `docs/diagrams/` | Architecture diagrams as code (HTML → animated SVG, `docs/diagrams/src`) |
| `docs/slo.md` | SLOs, error budget policy and burn-rate alerts (Spanish) |
| `docs/alerting.md` | Alert notifications to Telegram (Spanish) |
| `docs/runbooks/` | One runbook per alert: what it means and what to do (Spanish) |

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
- [x] Observability: Prometheus, Grafana and alerts for `demo-api`
- [x] SLOs for `demo-api`: 99.5 % availability and 99 % under 100 ms, multi-window burn-rate alerts with unit tests
- [x] Alerts to Telegram with a runbook link, routing tested in CI
- [x] Dead man's switch: healthchecks.io notifies on Telegram if alerts stop arriving (the PC goes down, power or internet is lost)
- [x] Descheduler: rebalances `demo-api` across nodes when a node comes back (e.g. after the laptop suspends)
- [ ] Secrets from OpenBao managed as code
- [ ] Clean up legacy test workloads

## License

[MIT](LICENSE)
