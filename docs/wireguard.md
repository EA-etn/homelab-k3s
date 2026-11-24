# Red privada WireGuard y firewall de las VPS

Dos VPS (RackNerd, Ashburn, EE. UU.) se suman al homelab. Para que hablen con la Pi y el PC sin
exponer nada a internet, todas las máquinas se unen en una **red privada cifrada con WireGuard**.

## Las máquinas

| Máquina | Dónde | IP en la VPN | Papel |
|---|---|---|---|
| `vps-estable` | VPS, IP pública | `10.10.0.1` | **Hub** de la VPN. Fuera del clúster: no se rompe en los experimentos |
| `devops-lab` | Pi, en casa | `10.10.0.2` | Control plane de k3s |
| `vps-lab` | VPS, IP pública | `10.10.0.3` | Laboratorio: será el worker de k3s (sustituye al portátil) |
| `nexcore` | Portátil | `10.10.0.4` | Estación de trabajo |

```
                vps-estable (hub, 10.10.0.1)  ← UDP 51820, el único puerto de la VPN abierto
               /            |             \
     devops-lab        vps-lab          nexcore
     (casa, NAT)       (Ashburn)        (casa o donde esté)
```

- La Pi y el portátil están detrás del router de casa: **son ellos los que llaman al hub** y lo
  mantienen con un saludo cada 25 s (`PersistentKeepalive`). No hay que abrir puertos en casa.
- Entre dos máquinas que no son el hub, el tráfico pasa por el hub. Las dos VPS están en el mismo
  centro de datos, así que la vuelta cuesta ~1 ms.

## Decisiones

| Decisión | Alternativa | Por qué |
|---|---|---|
| WireGuard propio | Tailscale, ZeroTier | Hay una VPS con IP pública, que es lo que Tailscale resuelve; así no depende de ningún servicio externo |
| Hub en la VPS estable | Hub en la VPS de laboratorio | Si el hub cae, cae la VPN entera: tiene que estar en la máquina que no se rompe a propósito |
| WireGuard en el sistema, fuera de k3s | Dentro del clúster | k3s hablará por esta red: si dependiera de k3s, al caer el clúster se caería también el camino para arreglarlo |
| Cada máquina genera su clave privada | Claves en el vault | La clave privada nunca sale de su máquina: ni en Git, ni en el vault, ni en `wg0.conf` (se carga con `PostUp`) |
| `ufw` gestionado por Ansible | Configurarlo a mano | El firewall queda escrito y se repite igual en una VPS nueva |

## El firewall de las VPS (rol `firewall`)

Por defecto se niega todo lo que entra. Se abre:

| Puerto | Dónde | Para qué |
|---|---|---|
| El de SSH (se pregunta a `sshd`) | Las dos | Administrar. Se abre **antes** de activar el firewall para no perder la conexión |
| 80, 443 TCP | Las dos | Webs (más adelante) |
| 51820 UDP | `vps-estable` | WireGuard |
| Todo lo que entra por `wg0` | Las dos | La red privada es de confianza |

En el hub, además, `ufw route allow in on wg0 out on wg0` deja pasar el tráfico entre dos máquinas
de la VPN, y `net.ipv4.ip_forward = 1` activa el reenvío.

## Ponerlo en marcha

1. Añadir al vault las contraseñas de `sudo` de las VPS (`vault_become_password_vps_lab` y
   `vault_become_password_vps_estable`, ver `ansible/vault.example.yml`):

   ```bash
   cd ansible
   EDITOR=nano ansible-vault edit group_vars/all/vault.yml
   ```

2. Simulación y después de verdad:

   ```bash
   ansible-playbook site.yml --ask-become-pass --ask-vault-pass --check --diff
   ansible-playbook site.yml --ask-become-pass --ask-vault-pass
   ```

   En la simulación, la primera vez, `PublicKey =` sale vacío y el arranque de WireGuard se salta:
   el paquete y las claves aún no existen. Se rellenan en la ejecución de verdad.

   El rol termina comprobando que **cada máquina llega a todas las demás** por la VPN (`ping` a cada
   `10.10.0.x`).

3. Comprobarlo a mano desde cualquier máquina:

   ```bash
   sudo wg show          # "latest handshake" reciente en cada peer
   ping -c 3 10.10.0.3
   ```

## El clúster por la VPN

El clúster pasa a ser **la Pi (control plane) + `vps-lab` (worker)**, y habla solo por `wg0`:

| Ajuste | Dónde | Efecto |
|---|---|---|
| `node-ip: 10.10.0.x` | `/etc/rancher/k3s/config.yaml` (roles `k3s_server` y `k3s_agent`) | Cada nodo se anuncia con su IP de la VPN |
| `flannel-iface: wg0` | El mismo archivo | La red de los pods (VXLAN) viaja dentro del túnel cifrado |
| `k3s_server_ip: 10.10.0.2` | `group_vars/all/main.yml` | El worker, el kubeconfig y `/etc/hosts` del portátil apuntan a la Pi por la VPN |
| `ufw allow from 10.42.0.0/16` y `10.43.0.0/16` | Rol `firewall` | Los pods pueden hablar con su propio nodo (kubelet, DNS, métricas) |

- El monitoring y la segunda réplica de demo-api se mudan solos a `vps-lab`: tiene la etiqueta
  `homelab/role=worker`.
- El portátil sale del clúster y queda como estación de trabajo. Como `kubectl` y los nombres
  `*.home.arpa` van por la VPN, **funcionan desde cualquier sitio**, no solo en casa.
- El portátil vuelve a suspenderse al cerrar la tapa: ya no es un nodo.

### Qué se ve desde internet

`vps-lab` tiene IP pública y Traefik escucha en sus puertos 80/443. Tras la migración, cualquiera
llegaba al login de Grafana enviando `Host: grafana.home.arpa` a esa IP. Se cerró así:

| Pieza | Qué hace |
|---|---|
| `externalTrafficPolicy: Local` en Traefik (`platform/traefik`) | Cada nodo entrega la petición a su propia copia de Traefik y Traefik ve la IP real de quien llama |
| Middleware `grafana-solo-vpn` (`platform/monitoring`) | Grafana solo acepta la VPN (`10.10.0.0/24`) y la red de casa; el resto recibe **403** |
| demo-api | Sigue pública: es la demo |

Se comprueba desde fuera de la VPN y desde dentro:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: grafana.home.arpa' http://216.45.53.36   # 403
curl -s -o /dev/null -w '%{http_code}\n' http://grafana.home.arpa                            # 302 (login), por la VPN
```

### La migración: reconstruir

Cambian las IPs de los nodos, así que en vez de tocar el clúster en marcha se reconstruye (ya
probado: ~12 min). Desde el portátil, en casa:

```bash
cd ansible
ansible-playbook reset.yml --ask-become-pass --ask-vault-pass -e confirmar=destruir
time ansible-playbook site.yml --ask-become-pass --ask-vault-pass
kubectl get nodes -o wide        # devops-lab y vps-lab, Ready, con IPs 10.10.0.x
```

`reset.yml` desinstala el agente en **cualquier** máquina que lo tenga, así que también limpia el
portátil aunque ya no esté en `k3s_agents`. Se pierden las métricas de Prometheus; lo demás vuelve
desde Git. El estado anterior (todo en casa) queda en la etiqueta `v1.0-casa`.
