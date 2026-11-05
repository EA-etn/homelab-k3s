#!/usr/bin/env bash
# Une este equipo al clúster k3s como nodo worker (agente).
#
# Uso, en el PC que se va a unir:
#   sudo K3S_TOKEN='<token>' ./bootstrap/join-worker.sh
#
# El token se lee en la Raspberry Pi (servidor) con:
#   sudo cat /var/lib/rancher/k3s/server/node-token
# Es una credencial del clúster: no la pegues en chats ni la subas a Git.
set -euo pipefail

K3S_VERSION="${K3S_VERSION:-v1.36.4+k3s1}"        # la misma versión que el servidor
SERVER_IP="${SERVER_IP:-10.9.8.100}"              # Raspberry Pi (control plane)
NODE_ROLE="${NODE_ROLE:-worker}"
KEEP_AWAKE="${KEEP_AWAKE:-true}"                  # portátil: no suspender al cerrar la tapa

: "${K3S_TOKEN:?Define K3S_TOKEN con el token del servidor (ver la cabecera del script)}"
[ "$(id -u)" -eq 0 ] || { echo "Ejecuta el script con sudo." >&2; exit 1; }

echo "==> Comprobando que el servidor responde en ${SERVER_IP}:6443"
if ! timeout 5 bash -c "</dev/tcp/${SERVER_IP}/6443" 2>/dev/null; then
  echo "No hay conexión con ${SERVER_IP}:6443. ¿Están en la misma red? ¿Hay un firewall?" >&2
  exit 1
fi

if [ "$KEEP_AWAKE" = "true" ]; then
  echo "==> Desactivando la suspensión al cerrar la tapa (systemd-logind)"
  mkdir -p /etc/systemd/logind.conf.d
  cat > /etc/systemd/logind.conf.d/10-homelab.conf <<'CONF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
CONF
  systemctl kill -s HUP systemd-logind   # recarga la configuración sin cerrar la sesión
fi

echo "==> Instalando el agente k3s ${K3S_VERSION}"
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="$K3S_VERSION" \
  K3S_URL="https://${SERVER_IP}:6443" \
  K3S_TOKEN="$K3S_TOKEN" \
  sh -s - agent --node-label "homelab/role=${NODE_ROLE}"

echo "==> Listo. Comprueba desde una máquina con kubectl:"
echo "    kubectl get nodes -o wide"
