<div align="center">

# Homelab k3s

**Un homelab de Kubernetes híbrido ARM + x86, gestionado con GitOps.**

[![Validate](https://github.com/EA-etn/homelab-k3s/actions/workflows/validate.yml/badge.svg)](https://github.com/EA-etn/homelab-k3s/actions/workflows/validate.yml)
![k3s](https://img.shields.io/badge/k3s-v1.36-FFC61C?logo=k3s&logoColor=black)
![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo&logoColor=white)
![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi%204-arm64-A22846?logo=raspberrypi&logoColor=white)
![WireGuard](https://img.shields.io/badge/red-WireGuard-88171A?logo=wireguard&logoColor=white)

[English](README.md) · **Español**

</div>

## Qué es

La parte de **plataforma** de mi laboratorio: un clúster k3s con el control plane en una Raspberry
Pi 4 en casa (arm64) y el worker en una VPS en la nube (amd64), unidos por una red WireGuard cifrada.
**Git es la única fuente de verdad**. ArgoCD vigila este repositorio y
mantiene el clúster sincronizado con él.

Las aplicaciones se construyen en otro sitio. [DevSecOps Pipeline](https://github.com/EA-etn/devsecops-pipeline)
prueba, escanea, firma y publica `demo-api` como imagen multi-arquitectura; este repo decide **qué
se ejecuta en el clúster**.

<img src="docs/diagrams/es/02-hybrid.svg" alt="Arquitectura híbrida: una Raspberry Pi en casa (control plane de k3s) y el portátil se conectan por túneles WireGuard a una VPS hub fuera del clúster; la VPS worker en Ashburn ejecuta demo-api y el monitoring, lee Git con ArgoCD, avisa por Telegram y manda un latido a healthchecks.io; desde internet solo responde demo-api, Grafana devuelve 403" width="100%">

<sub><a href="https://raw.githubusercontent.com/EA-etn/homelab-k3s/main/docs/diagrams/es/02-hybrid.png">🔍 Ver a tamaño completo</a></sub>

Los nodos hablan solo por la VPN (`wg0`): k3s, Flannel y kubectl nunca cruzan internet en claro. El
hub vive en una segunda VPS que queda fuera del clúster, así que romper el clúster a propósito nunca
tumba la red ([docs/wireguard.md](docs/wireguard.md)).

<details>
<summary>Antes: todo en casa (<code>v1.0-casa</code>)</summary>

<img src="docs/diagrams/es/01-architecture.svg" alt="Arquitectura de v1.0-casa: los repos de GitHub alimentan a ArgoCD, que sincroniza un clúster k3s en una Raspberry Pi y un PC; Prometheus, Grafana y Alertmanager corren en el PC y avisan por Telegram; healthchecks.io vigila las alertas desde fuera" width="100%">

El portátil se suspendía y se movía: cuando se iba, se llevaba la mitad de la app y todo el
monitoring (experimentos de chaos 4a y 4b). Por eso el worker pasó a una VPS. Release:
[`v1.0-casa`](https://github.com/EA-etn/homelab-k3s/releases/tag/v1.0-casa).
</details>

## Lo más destacado

| | |
|---|---|
| ☸️ **Clúster híbrido** | Control plane de k3s en una Raspberry Pi 4 en casa (arm64, arranca desde SSD) + worker en una VPS en la nube (amd64). La misma imagen multi-arquitectura corre en los dos |
| 🔒 **Red privada** | WireGuard entre casa y la nube, gestionado con Ansible: cada máquina genera su clave privada, que nunca sale de ella. `ufw` en las VPS, y Grafana solo responde a la VPN (`403` desde internet) |
| 🔄 **GitOps** | App of Apps: un solo `kubectl apply`, todo lo demás sale de `apps/`. Self-heal y prune activados |
| 🎯 **SLOs** | 99,5 % de disponibilidad y 99 % de peticiones en menos de 100 ms, con presupuesto de errores y alertas multi-ventana por burn rate ([docs/slo.md](docs/slo.md)) |
| 🚨 **Respuesta a incidentes** | Las alertas llegan a Telegram con el enlace al [runbook](docs/runbooks/README.md) de esa alerta. Un [dead man's switch](docs/alerting.md#dead-mans-switch) fuera de casa avisa si lo que cae es el propio sistema de alertas |
| 🧪 **Alertas con tests** | Tests unitarios con `promtool` para cada alerta de SLO y comprobaciones con `amtool` de las rutas y del mensaje de Telegram, en el CI |
| 📊 **Observabilidad** | kube-prometheus-stack con dashboards como código, 30 días de retención y tráfico sintético a través del Ingress |
| 🛠️ **Reconstruible** | Un playbook de [Ansible](docs/ansible.md) monta los nodos, k3s, los Secrets y ArgoCD; ArgoCD hace el resto desde Git (comprobado: **destruido y reconstruido desde cero en ~12 minutos** con `reset.yml` + `site.yml`; una segunda ejecución da `changed=0`). El paso de casa a híbrido fue también una reconstrucción |
| 🔐 **Sin secretos en claro** | Los tokens y contraseñas viven en Secrets de Kubernetes, nunca en Git en claro. El Ansible Vault que los recrea va cifrado, y tanto el CI como un hook de Git rechazan uno sin cifrar |

## Cuando algo falla

Lo que importa de una plataforma es lo que pasa en un mal día. Cada experimento, con su hipótesis y sus hallazgos: [docs/chaos.md](docs/chaos.md).

Estos experimentos se hicieron sobre `v1.0-casa` (Pi + portátil). Lo siguiente es repetir los de nodos sobre el clúster híbrido.

| Si… | Qué pasa | Evidencia |
|---|---|---|
| Muere un pod | Kubernetes lo sustituye mientras la otra réplica sigue atendiendo | ✅ Test de chaos: 300 peticiones mientras se mataba un pod, 0 fallidas |
| Cae un nodo | La réplica del otro nodo sigue atendiendo; la regla de reparto obligatoria ignora el nodo caído | ✅ Test de chaos: al apagar la Pi se vio que la entrada y el DNS solo vivían en ella (0 % atendido, ninguna alerta). Tras el arreglo: `TargetDown` en Telegram en 10 min y la app atiende en parte; el resto necesita 3 nodos de control plane |
| El nodo vuelve | El Descheduler devuelve un pod en menos de 5 minutos: otra vez una réplica por nodo | ✅ Test con `cordon` / `uncordon` |
| Los errores o la latencia queman el presupuesto | Llega a Telegram una alerta por burn rate con su runbook | ✅ Test de chaos: con un 20 % de errores, alerta crítica en ~21 min, mientras los pods seguían `Running` |
| Cae la propia máquina del monitoring | healthchecks.io deja de recibir la señal de vida y avisa desde fuera de casa | ✅ Test de chaos: PC apagado → healthchecks.io avisó por Telegram y email |
| Se pierde el clúster entero | `reset.yml` + `site.yml` lo reconstruyen: Ansible crea k3s, los Secrets y ArgoCD; ArgoCD trae el resto desde Git | ✅ Destruido y reconstruido: k3s + ArgoCD en 4 min 26 s, todas las apps sanas en ~12 min |
| Alguien cambia el clúster a mano | ArgoCD lo deja como dice Git (`selfHeal`) | Configurado |
| Se despliega una versión mala | Los pods viejos siguen atendiendo; `git revert` y ArgoCD vuelve atrás | ✅ Test de chaos: imagen inexistente → sin impacto para los usuarios, aviso en ~10 min, arreglado en 3 min con un revert |

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
| `docs/wireguard.md` | La VPN, el firewall de las VPS y el paso al clúster híbrido |
| `docs/diagrams/` | Diagramas de arquitectura como código (HTML → SVG animado, `docs/diagrams/src`) |
| `docs/slo.md` | SLOs, política de presupuesto de errores y alertas por burn rate |
| `docs/alerting.md` | Notificaciones de alertas a Telegram |
| `docs/runbooks/` | Un runbook por alerta: qué significa y qué hacer |

## Puesta en marcha

Con Ansible, desde el portátil ([detalles](docs/ansible.md)):

```bash
cd ansible
ansible-playbook site.yml --ask-become-pass --ask-vault-pass --check --diff   # simulación
ansible-playbook site.yml --ask-become-pass --ask-vault-pass                  # de verdad

# Ver cómo ArgoCD crea todo lo que hay en apps/
kubectl -n argocd get applications
```

<details>
<summary>A mano, sin Ansible (antiguo: red de casa, antes de la VPN)</summary>

```bash
# 1. Unir el portátil como worker (se ejecuta en el portátil; el token sale de la Pi)
sudo K3S_TOKEN='<token>' ./bootstrap/join-worker.sh

# 2. Entregar el clúster a Git
kubectl apply -f bootstrap/root-app.yaml
```
</details>

## Licencia

[MIT](LICENSE)
