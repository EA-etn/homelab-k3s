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

## Lo que viene después

Este paso solo crea la red. k3s sigue usando la red de casa (`10.9.8.0/24`). Después: `vps-lab` se une
al clúster como worker por `wg0`, el monitoring se mueve allí y el portátil sale del clúster.
