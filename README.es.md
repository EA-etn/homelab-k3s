<div align="center">

# Homelab k3s

**Un homelab de Kubernetes híbrido ARM + x86, gestionado con GitOps.**

[![Validate](https://github.com/EA-etn/homelab-k3s/actions/workflows/validate.yml/badge.svg)](https://github.com/EA-etn/homelab-k3s/actions/workflows/validate.yml)
![k3s](https://img.shields.io/badge/k3s-v1.36-FFC61C?logo=k3s&logoColor=black)
![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo&logoColor=white)
![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi%204-arm64-A22846?logo=raspberrypi&logoColor=white)

[English](README.md) · **Español**

</div>

## Qué es

La parte de **plataforma** de mi laboratorio: un clúster k3s en una Raspberry Pi 4 (arm64) y un
portátil (amd64), donde **Git es la única fuente de verdad**. ArgoCD vigila este repositorio y
mantiene el clúster sincronizado con él.

Las aplicaciones se construyen en otro sitio. [DevSecOps Pipeline](https://github.com/EA-etn/devsecops-pipeline)
prueba, escanea, firma y publica `demo-api` como imagen multi-arquitectura; este repo decide **qué
se ejecuta en el clúster**.

```
devsecops-pipeline ──(imagen firmada + chart)──┐
                                               ▼
homelab-k3s ──(apps/)──► ArgoCD ──► k3s: Raspberry Pi 4 (arm64) + portátil (amd64)
```

## Estructura

| Ruta | Para qué sirve |
|---|---|
| `bootstrap/join-worker.sh` | Une un equipo al clúster como agente k3s (misma versión que el servidor) |
| `bootstrap/root-app.yaml` | App of Apps: la única Application que se aplica a mano |
| `apps/` | Una Application de ArgoCD por carga de trabajo. Añade un archivo aquí para desplegar algo |
| `platform/monitoring/` | Dashboards de Grafana, alertas de Prometheus y SLOs como código |
| `tests/slo/` | Tests unitarios de las reglas y alertas del SLO (`promtool`, en el CI) |
| `tests/alertmanager/` | Validación de la configuración de Alertmanager, sus rutas y el mensaje de Telegram (`amtool`, en el CI) |
| `docs/inventory.md` | Hardware, red y software instalado |
| `docs/slo.md` | SLOs, política de presupuesto de errores y alertas por burn rate |
| `docs/alerting.md` | Notificaciones de alertas a Telegram |
| `docs/runbooks/` | Un runbook por alerta: qué significa y qué hacer |

## Puesta en marcha

```bash
# 1. Unir el portátil como worker (se ejecuta en el portátil; el token sale de la Pi)
sudo K3S_TOKEN='<token>' ./bootstrap/join-worker.sh

# 2. Entregar el clúster a Git
kubectl apply -f bootstrap/root-app.yaml

# 3. Ver cómo ArgoCD crea todo lo que hay en apps/
kubectl -n argocd get applications
```

## Hoja de ruta

- [x] Control plane de k3s en una Raspberry Pi 4 arrancando desde SSD
- [x] ArgoCD y OpenBao (secretos) instalados
- [x] Portátil unido como worker amd64
- [x] App of Apps: el clúster gestionado desde este repo
- [x] `demo-api` desplegada en los dos nodos (una réplica por arquitectura)
- [x] Observabilidad: Prometheus, Grafana y alertas de `demo-api`
- [x] SLOs de `demo-api`: 99,5 % de disponibilidad y 99 % en menos de 100 ms, alertas multi-ventana por burn rate con tests
- [x] Alertas a Telegram con enlace al runbook, rutas probadas en el CI
- [ ] Secretos de OpenBao gestionados como código
- [ ] Limpiar las cargas de prueba antiguas

## Licencia

[MIT](LICENSE)
