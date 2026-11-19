# Ansible: el homelab con un comando

La carpeta [`ansible/`](../ansible) describe cómo se montan las máquinas y el clúster. Con ella, el
homelab se puede **reconstruir desde cero** con un comando, o **comprobar** que sigue como debe.

## Qué hace cada capa

| Capa | Quién la monta |
|---|---|
| Ubuntu en la Pi y en el PC | A mano (grabar la imagen y activar SSH): es lo único que no se automatiza |
| Paquetes, cgroups de la Pi, tapa del portátil | Ansible · rol `common` |
| k3s: servidor en la Pi y agente en el PC | Ansible · roles `k3s_server` y `k3s_agent` |
| Secrets del clúster (Telegram, healthchecks.io, Grafana) | Ansible · rol `cluster_secrets`, desde el vault cifrado |
| ArgoCD y la Application raíz | Ansible · rol `argocd` |
| demo-api, monitoring, Descheduler, SLOs, dashboards… | **ArgoCD**, desde Git (`apps/`) |
| `/etc/hosts` y `kubectl` en el PC | Ansible · rol `workstation` |
| Los 30 días de métricas de Prometheus | Nadie: se pierden al reconstruir (son datos, no configuración) |

```
site.yml
 1. common          → todas las máquinas
 2. k3s_server      → la Pi
 3. k3s_agent       → el PC
 4. cluster_secrets → la Pi (crea los Secrets antes de que ArgoCD despliegue monitoring)
    argocd          → la Pi (instala ArgoCD y aplica bootstrap/root-app.yaml)
 5. workstation     → el PC
```

Cada tarea comprueba antes de actuar: si k3s ya está en la versión de
[`group_vars/all/main.yml`](../ansible/group_vars/all/main.yml) o ArgoCD ya existe, no hace nada.
Por eso el playbook se puede ejecutar **siempre**, sobre máquinas nuevas o sobre el clúster actual
(idempotencia).

## Los secretos: Ansible Vault

Los secretos van en `ansible/group_vars/all/vault.yml`, **cifrado** con `ansible-vault` (AES-256). Se
sube a Git cifrado: sin la contraseña del vault es ilegible. La contraseña la guardas tú, en tu
gestor de contraseñas, y **nunca** va en Git ni en un chat.

### La contraseña del vault

El archivo cifrado es público para siempre: alguien podría intentar adivinar la contraseña probando
millones de combinaciones en su ordenador, sin límite de intentos. Por eso tiene que ser **larga y
aleatoria**:

- 5 o 6 palabras al azar (por ejemplo, generadas por tu gestor de contraseñas), o
- 20 caracteres o más, generados al azar.

Nunca una contraseña que uses en otro sitio. Guárdala en tu gestor de contraseñas: sin ella no se
puede reconstruir el homelab.

### Dos controles para no subirlo en claro

| Control | Cuándo actúa |
|---|---|
| **Hook de Git** (`.githooks/pre-commit`) | **Antes** del commit, en tu PC: si el vault no está cifrado, el commit no se hace |
| **CI** (job Ansible, paso "El vault está cifrado") | En el PR. Si salta, el secreto ya está en GitHub y hay que cambiarlo |

El hook se activa una vez en cada clon del repo:

```bash
git config core.hooksPath .githooks
```

### Si se filtra la contraseña del vault

Git guarda todas las versiones del archivo, así que cambiar la contraseña (`ansible-vault rekey`)
**no basta**: con la vieja se pueden descifrar las versiones antiguas. Hay que cambiar **los secretos
de dentro**: crear un token nuevo del bot en @BotFather, un check nuevo en healthchecks.io, otra
contraseña de Grafana… y actualizar el vault.

## Puesta en marcha (en el PC)

**1. Instalar Ansible:**

```bash
sudo apt install -y ansible
```

**2. Acceso por SSH a la Pi con clave** (si ya entras sin contraseña, sáltatelo):

```bash
ssh-keygen -t ed25519            # solo si no tienes clave
ssh-copy-id antonio@10.9.8.100   # tu usuario de la Pi
```

Si tu usuario en la Pi no es `antonio`, cámbialo en [`ansible/inventory.yml`](../ansible/inventory.yml).

**3. Activar el control del vault** (una vez):

```bash
git config core.hooksPath .githooks
```

**4. Crear el vault** (con una contraseña larga: ver "La contraseña del vault"):

```bash
cd ansible
cp vault.example.yml group_vars/all/vault.yml
nano group_vars/all/vault.yml           # rellena los valores reales
ansible-vault encrypt group_vars/all/vault.yml
```

Las contraseñas de `sudo` de la Pi y del PC son distintas: la de la Pi va en el vault
(`vault_become_password_pi`, la usa [`host_vars/devops-lab.yml`](../ansible/host_vars/devops-lab.yml)),
y la del PC se escribe al ejecutar el playbook (`--ask-become-pass`).

Para un clúster que ya existe, `vault_k3s_token` es el token actual del servidor (en la Pi:
`sudo cat /var/lib/rancher/k3s/server/node-token`). Cópialo directamente al vault: no lo pegues en
ningún otro sitio.

## Usarlo

**Simulación** (no cambia nada; muestra qué cambiaría):

```bash
cd ansible
ansible-playbook site.yml --ask-become-pass --ask-vault-pass --check --diff
```

`--ask-become-pass` pide tu contraseña de `sudo` **del PC** (la de la Pi sale del vault), y
`--ask-vault-pass`, la del vault. En modo
simulación, las tareas que hablan con el clúster (`kubectl`) se saltan: solo se comprueba la parte de
las máquinas.

**De verdad:**

```bash
ansible-playbook site.yml --ask-become-pass --ask-vault-pass
```

Sobre el clúster actual, lo normal es que casi todo salga `ok` (ya estaba bien) y nada `changed`.

## Problemas conocidos

| Síntoma | Causa | Solución |
|---|---|---|
| `Failed to update apt cache` sin más detalle | Un repositorio de terceros con la clave de firma caducada (en el PC, el de HashiCorp). `apt update` a mano solo avisa, pero Ansible lo trata como error | Renovar la clave del repositorio (`sudo apt update` muestra cuál falla) |
| Los Secrets salían `changed` en cada ejecución | Se enviaban con `stringData`, que Kubernetes guarda como `data`: `kubectl apply` veía siempre una diferencia | Se envían con `data` en base64 |
| `Timed out waiting for become success or become password prompt` en el PC | Ubuntu 25.10+ usa **sudo-rs** como `sudo`, y su pregunta de contraseña no es la que Ansible espera | El PC usa el `sudo` clásico, que Ubuntu mantiene como `sudo.ws` ([`host_vars/nexcore.yml`](../ansible/host_vars/nexcore.yml)) |

## Reconstruir desde cero

Hay dos niveles de "desde cero":

| Nivel | Qué se borra | Cómo |
|---|---|---|
| **El clúster** | k3s y todo lo que vive en él; Ubuntu se queda | `reset.yml` (abajo) |
| Las máquinas | Todo, incluido Ubuntu | Grabar Ubuntu de nuevo, con la misma IP fija y SSH; copiar la clave SSH a la Pi |

En los dos casos se levanta igual: con `site.yml`.

### Borrar el clúster: `reset.yml`

Es el "destroy" del homelab: ejecuta los desinstaladores que deja k3s (`k3s-agent-uninstall.sh` en
el PC y `k3s-uninstall.sh` en la Pi). Sin `-e confirmar=destruir` se cancela sin tocar nada.

```bash
cd ansible
ansible-playbook reset.yml --ask-become-pass --ask-vault-pass -e confirmar=destruir
```

Se pierde lo que no está en Git: las métricas de Prometheus. Todo lo demás vuelve solo: los Secrets
salen del vault, y las apps, alertas y dashboards, de Git a través de ArgoCD.

Mientras el clúster no existe, healthchecks.io avisará de que el monitoring está caído: es lo
esperado.

### Volver a levantarlo, cronometrado

```bash
time ansible-playbook site.yml --ask-become-pass --ask-vault-pass
kubectl -n argocd get applications -w    # hasta que todo esté Synced y Healthy (Ctrl+C para salir)
```

Y comprobar que todo funciona como antes: `curl http://demo-api.home.arpa/info`, Grafana con sus
dashboards, una alerta de prueba en Telegram y healthchecks.io en verde.

¿Por qué no Terraform? Terraform **crea máquinas** a través de la API de un proveedor (AWS, Azure…).
Aquí las máquinas son físicas y ya existen: solo hay que **configurarlas**, que es el trabajo de
Ansible.

## Actualizar k3s

Cambia `k3s_version` en `group_vars/all/main.yml` (primero la Pi y el PC deben ir a la misma versión)
y ejecuta el playbook. El instalador oficial actualiza k3s en su sitio.
