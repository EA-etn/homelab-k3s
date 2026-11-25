# Inventario del homelab

Estado registrado el 2026-11-24, tras pasar al clúster híbrido (casa + nube). El estado anterior,
todo en casa, está en la release [`v1.0-casa`](https://github.com/EA-etn/homelab-k3s/releases/tag/v1.0-casa).
Actualízalo cuando cambie el hardware o lo instalado.

## Máquinas

| Máquina | Equipo | Arquitectura | CPU | RAM | Disco | Sistema | IP de la VPN | Papel |
|---|---|---|---|---|---|---|---|---|
| `devops-lab` | Raspberry Pi 4 Model B Rev 1.5, en casa | arm64 | 4 núcleos Cortex-A72 | 8 GB | SSD 219 GB | Ubuntu 24.04.4 LTS | `10.10.0.2` | **control plane** de k3s |
| `vps-lab` | VPS KVM (RackNerd, Ashburn, EE. UU.) | amd64 | 4 vCPU Xeon E5-2690 v4 | 4 GB | 60 GB SSD | Ubuntu 24.04.5 LTS | `10.10.0.3` | **worker** de k3s |
| `vps-estable` | VPS KVM (RackNerd, Ashburn, EE. UU.) | amd64 | 4 vCPU Xeon E5-2680 v2 | 4 GB | 60 GB SSD | Ubuntu 24.04.5 LTS | `10.10.0.1` | Hub de WireGuard, **fuera del clúster** |
| `nexcore` | Portátil Intel Core i7-7500U | amd64 | 2 núcleos / 4 hilos | 11 GB | 469 GB | Ubuntu 26.04.1 LTS | `10.10.0.4` | Estación de trabajo (fue worker hasta el 2026-11-24) |

- **Redes:** VPN WireGuard `10.10.0.0/24` ([wireguard.md](wireguard.md)); red de casa `10.9.8.0/24`
  (la Pi es `10.9.8.100`); pods `10.42.0.0/16`; Services `10.43.0.0/16`.
- **IPs públicas:** `vps-lab` 216.45.53.36 y `vps-estable` 107.175.134.57, con `ufw`: SSH, 80/443 y,
  en el hub, 51820/udp.
- La Pi arranca desde SSD: ver el [runbook de la migración de microSD a SSD](https://github.com/antonio-devops-lab/devops-lab/blob/main/docs/sd-to-ssd-migration.md) en el repo antiguo `devops-lab` (archivado).
- El acceso al clúster se hace desde `nexcore` con `kubectl` y `helm`, por la VPN (kubeconfig
  apuntando a `10.10.0.2:6443`): funciona también fuera de casa.

## Software del clúster

| Componente | Versión / estado | Namespace | Gestionado por |
|---|---|---|---|
| k3s | v1.36.4+k3s1 | — | Ansible (roles `k3s_server` y `k3s_agent`) |
| Traefik (Ingress) | incluido en k3s; una copia por nodo, `externalTrafficPolicy: Local` | `kube-system` | k3s + ArgoCD (`apps/traefik.yaml`) |
| metrics-server | incluido en k3s | `kube-system` | k3s |
| local-path-provisioner | incluido en k3s | `kube-system` | k3s |
| ArgoCD | v3.6.1 (manifiestos oficiales) | `argocd` | Ansible (rol `argocd`) |
| `root` (App of Apps) | Synced / Healthy | `argocd` | este repo (`bootstrap/root-app.yaml`) |
| `demo-api` | 2 réplicas, una por nodo | `demo-api` | ArgoCD (`apps/demo-api.yaml`) |
| `monitoring` (kube-prometheus-stack 92.17.1) | Prometheus, Grafana, Alertmanager en `vps-lab`; node-exporter en los dos nodos | `monitoring` | ArgoCD (`apps/monitoring.yaml`) |
| `monitoring-extras` | dashboards, alertas y SLOs de `demo-api`; Grafana solo desde la VPN | `monitoring` | ArgoCD (`apps/monitoring-extras.yaml`) |
| `descheduler` (chart 0.37.0) | reequilibra `demo-api` entre nodos cada 5 min | `descheduler` | ArgoCD (`apps/descheduler.yaml`) |

## Observaciones

- Grafana: `http://grafana.home.arpa` (en `/etc/hosts` del portátil → `10.10.0.2`, por la VPN).
  Desde internet responde **403**. Usuario y contraseña en el Secret `monitoring/grafana-admin`, que
  crea Ansible desde el vault.
- `demo-api` responde en `http://demo-api.home.arpa` (igual, por la VPN). También llega por la IP
  pública de `vps-lab` con esa cabecera `Host`: es la demo y no guarda nada.
- Las métricas de Prometheus empezaron de cero el 2026-11-24 (la reconstrucción no las conserva).

### Historia (`v1.0-casa`)

- `argocd-repo-server` acumulaba 29 reinicios en la Pi (probablemente la sonda de liveness con
  `timeout=1s` bajo carga). La reconstrucción lo dejó a cero: vigilar si vuelve a subir.
- 2026-11-12: limpiados los restos del proyecto antiguo `devops-lab`: `devops-lab-app` (y su credencial de repo en ArgoCD), `nginx-test`, `postgres-test` (con su PVC), `myapp-secret-test` y OpenBao con su agent injector (estaba en modo dev, sin datos persistentes y sin uso). Revocadas la deploy key del repo antiguo y el token de lectura de `ghcr.io`. El namespace `default` queda vacío.

## Incidencias

| Fecha | Problema | Causa | Solución |
|---|---|---|---|
| 2026-11-05 | El agente de `nexcore` se quedaba en `not authorized` | El token se copió con texto de más (empezaba por `anto`, no por `K10`) | Copiar solo la línea del token; `join-worker.sh` ahora valida que empiece por `K10` |
| 2026-11-24 | El agente de `vps-lab` se registró como `racknerd-5663cd5` y Ansible no lo encontraba | k3s usa el hostname de la máquina como nombre del nodo | Hostname del inventario en el rol `common` y `node-name` en `config.yaml` (#36) |
| 2026-11-24 | Grafana respondía desde internet por la IP pública de `vps-lab` | Traefik escucha en los 80/443 de cada nodo, y ahora un nodo tiene IP pública | `externalTrafficPolicy: Local` + `ipAllowList` solo VPN y casa (#37) |
