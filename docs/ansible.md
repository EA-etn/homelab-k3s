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

El CI comprueba en cada PR que el vault está cifrado: si alguien lo sube en claro, el check falla.
Aun así, ese secreto ya se habría publicado y habría que cambiarlo. Por eso, antes de cada commit:

```bash
head -1 ansible/group_vars/all/vault.yml   # debe decir $ANSIBLE_VAULT;1.1;AES256
```

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

**3. Crear el vault:**

```bash
cd ansible
cp group_vars/all/vault.example.yml group_vars/all/vault.yml
nano group_vars/all/vault.yml           # rellena los valores reales
ansible-vault encrypt group_vars/all/vault.yml
```

Para un clúster que ya existe, `vault_k3s_token` es el token actual del servidor (en la Pi:
`sudo cat /var/lib/rancher/k3s/server/node-token`). Cópialo directamente al vault: no lo pegues en
ningún otro sitio.

## Usarlo

**Simulación** (no cambia nada; muestra qué cambiaría):

```bash
cd ansible
ansible-playbook site.yml --ask-become-pass --ask-vault-pass --check --diff
```

`--ask-become-pass` pide tu contraseña de `sudo`, y `--ask-vault-pass`, la del vault. En modo
simulación, las tareas que hablan con el clúster (`kubectl`) se saltan: solo se comprueba la parte de
las máquinas.

**De verdad:**

```bash
ansible-playbook site.yml --ask-become-pass --ask-vault-pass
```

Sobre el clúster actual, lo normal es que casi todo salga `ok` (ya estaba bien) y nada `changed`.

## Reconstruir desde cero

1. Grabar Ubuntu en la Pi y en el PC, con la misma IP fija y SSH activado.
2. Copiar la clave SSH a la Pi (paso 2 de la puesta en marcha).
3. Clonar este repo en el PC e instalar Ansible.
4. Ejecutar el playbook. Tarda unos 15–20 minutos.
5. Esperar a que ArgoCD sincronice: `kubectl -n argocd get applications`.

## Actualizar k3s

Cambia `k3s_version` en `group_vars/all/main.yml` (primero la Pi y el PC deben ir a la misma versión)
y ejecuta el playbook. El instalador oficial actualiza k3s en su sitio.
