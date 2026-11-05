# Inventario del homelab

Estado registrado el 2026-11-05. Actualízalo cuando cambie el hardware o lo instalado.

## Nodos

| Nodo | Equipo | Arquitectura | CPU | RAM | Disco | Sistema | IP | Rol |
|---|---|---|---|---|---|---|---|---|
| `devops-lab` | Raspberry Pi 4 Model B Rev 1.5 | arm64 | 4 núcleos Cortex-A72 | 8 GB | SSD 219 GB | Ubuntu 24.04.4 LTS | `10.9.8.100` | control plane + worker |
| `nexcore` | Portátil Intel Core i7-7500U | amd64 | 2 núcleos / 4 hilos | 11 GB | 469 GB | Ubuntu 26.04.1 LTS | `10.9.8.37` | worker (unido el 2026-11-05) |

- Red local: `10.9.8.0/24`. Red de pods de k3s: `10.42.0.0/16`.
- La Pi arranca desde SSD (ver la migración de SD a SSD en el repo antiguo `devops-lab`).
- `nexcore` es un portátil: `bootstrap/join-worker.sh` desactiva la suspensión al cerrar la tapa.
- El acceso al clúster se hace desde `nexcore` con `kubectl` y `helm` (kubeconfig apuntando a `10.9.8.100:6443`).

## Software del clúster

| Componente | Versión / estado | Namespace | Gestionado por |
|---|---|---|---|
| k3s | v1.36.4+k3s1 | — | instalación manual |
| Traefik (Ingress) | incluido en k3s | `kube-system` | k3s |
| metrics-server | incluido en k3s | `kube-system` | k3s |
| local-path-provisioner | incluido en k3s | `kube-system` | k3s |
| ArgoCD | en ejecución (59 días) | `argocd` | instalación previa |
| OpenBao + agent injector | en ejecución | `openbao` | instalación previa |
| `root` (App of Apps) | Synced / Healthy | `argocd` | este repo (`bootstrap/root-app.yaml`) |
| `demo-api` | 2 réplicas: una en `devops-lab`, otra en `nexcore` | `demo-api` | ArgoCD (`apps/demo-api.yaml`) |
| `monitoring` (kube-prometheus-stack 92.17.1) | Prometheus, Grafana, Alertmanager en `nexcore`; node-exporter en ambos nodos | `monitoring` | ArgoCD (`apps/monitoring.yaml`) |
| `devops-lab-app` | en ejecución | `default` | ArgoCD (repo antiguo `devops-lab`) |
| `nginx-test`, `postgres-test` | pruebas | `default` | manifiestos sueltos |
| `myapp-secret-test` | `Unknown` (prueba de OpenBao colgada) | `default` | manifiestos sueltos |

## Observaciones

- Grafana: `http://grafana.home.arpa` (entrada en `/etc/hosts` → `10.9.8.100`). Usuario y contraseña en el Secret `monitoring/grafana-admin`, creado a mano (no está en Git).

- `demo-api` responde en `http://demo-api.home.arpa` (entrada en `/etc/hosts` de `nexcore` → `10.9.8.100`, Traefik).

- `argocd-repo-server` acumula 29 reinicios: revisar memoria (`kubectl -n argocd describe pod`).
- Las pruebas de `default` se limpiarán cuando este repo gestione el clúster.

## Incidencias

| Fecha | Problema | Causa | Solución |
|---|---|---|---|
| 2026-11-05 | El agente de `nexcore` se quedaba en `not authorized` | El token se copió con texto de más (empezaba por `anto`, no por `K10`) | Copiar solo la línea del token; `join-worker.sh` ahora valida que empiece por `K10` |
