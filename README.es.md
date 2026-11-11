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

<img src="docs/diagrams/es/01-architecture.svg" alt="Arquitectura: los repos de GitHub alimentan a ArgoCD, que sincroniza un clúster k3s en una Raspberry Pi y un PC; Prometheus, Grafana y Alertmanager corren en el PC y avisan por Telegram" width="100%">

<sub><a href="https://raw.githubusercontent.com/EA-etn/homelab-k3s/main/docs/diagrams/es/01-architecture.png">🔍 Ver a tamaño completo</a></sub>

## Lo más destacado

| | |
|---|---|
| ☸️ **Clúster híbrido** | Control plane k3s en una Raspberry Pi 4 (arm64, arranca desde SSD) + portátil como worker (amd64). La misma imagen multi-arquitectura corre en los dos |
| 🔄 **GitOps** | App of Apps: un único `kubectl apply` manual, todo lo demás sale de `apps/`. Self-heal y prune activados |
| 📊 **Observabilidad** | kube-prometheus-stack con dashboards como código, 30 días de retención y tráfico sintético a través del ingress |
| 🎯 **SLOs** | 99,5 % de disponibilidad y 99 % de peticiones en menos de 100 ms, presupuesto de errores y alertas multi-ventana por burn rate ([docs/slo.md](docs/slo.md)) |
| 🚨 **Respuesta a incidentes** | Alertas a Telegram con enlace al [runbook](docs/runbooks/README.md) de cada alerta, inhibición y silencios |
| 🧪 **Alertas probadas** | Tests unitarios con `promtool` para cada alerta del SLO y comprobaciones con `amtool` de rutas y mensaje de Telegram, en el CI |
| 🔐 **Sin secretos en Git** | La contraseña de Grafana y el token de Telegram viven en Secrets creados a mano; el repo es público |

## Estructura

| Ruta | Para qué sirve |
|---|---|
| `ansible/` | Monta las máquinas y el clúster desde cero: k3s, secretos (Ansible Vault) y ArgoCD ([docs](docs/ansible.md)) |
| `bootstrap/join-worker.sh` | Alternativa manual a Ansible: une un equipo al clúster como agente k3s |
| `bootstrap/root-app.yaml` | App of Apps: la única Application que se aplica a mano |
| `apps/` | Una Application de ArgoCD por carga de trabajo. Añade un archivo aquí para desplegar algo |
| `platform/monitoring/` | Dashboards de Grafana, alertas de Prometheus y SLOs como código |
| `tests/slo/` | Tests unitarios de las reglas y alertas del SLO (`promtool`, en el CI) |
| `tests/alertmanager/` | Validación de la configuración de Alertmanager, sus rutas y el mensaje de Telegram (`amtool`, en el CI) |
| `docs/inventory.md` | Hardware, red y software instalado |
| `docs/diagrams/` | Diagramas de arquitectura como código (HTML → SVG animado, `docs/diagrams/src`) |
| `docs/slo.md` | SLOs, política de presupuesto de errores y alertas por burn rate |
| `docs/alerting.md` | Notificaciones de alertas a Telegram |
| `docs/runbooks/` | Un runbook por alerta: qué significa y qué hacer |

## Puesta en marcha

Con Ansible, desde el PC ([detalles](docs/ansible.md)):

```bash
cd ansible
ansible-playbook site.yml --ask-become-pass --ask-vault-pass --check --diff   # simulación
ansible-playbook site.yml --ask-become-pass --ask-vault-pass                  # de verdad

# Ver cómo ArgoCD crea todo lo que hay en apps/
kubectl -n argocd get applications
```

<details>
<summary>A mano, sin Ansible</summary>

```bash
# 1. Unir el portátil como worker (se ejecuta en el portátil; el token sale de la Pi)
sudo K3S_TOKEN='<token>' ./bootstrap/join-worker.sh

# 2. Entregar el clúster a Git
kubectl apply -f bootstrap/root-app.yaml
```
</details>

## Hoja de ruta

- [x] Control plane de k3s en una Raspberry Pi 4 arrancando desde SSD
- [x] ArgoCD y OpenBao (secretos) instalados
- [x] Portátil unido como worker amd64
- [x] App of Apps: el clúster gestionado desde este repo
- [x] `demo-api` desplegada en los dos nodos (una réplica por arquitectura)
- [x] Observabilidad: Prometheus, Grafana y alertas de `demo-api`
- [x] SLOs de `demo-api`: 99,5 % de disponibilidad y 99 % en menos de 100 ms, alertas multi-ventana por burn rate con tests
- [x] Alertas a Telegram con enlace al runbook, rutas probadas en el CI
- [x] Dead man's switch: healthchecks.io avisa por Telegram si las alertas dejan de llegar (se apaga el PC, se va la luz o internet)
- [x] Descheduler: reequilibra `demo-api` entre nodos cuando un nodo vuelve (p. ej. tras suspenderse el portátil)
- [ ] Ansible: reconstruir el homelab desde cero con un comando (código listo, falta la reconstrucción real)
- [ ] Secretos de OpenBao gestionados como código
- [ ] Limpiar las cargas de prueba antiguas

## Licencia

[MIT](LICENSE)
