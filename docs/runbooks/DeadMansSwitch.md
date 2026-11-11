# Dead man's switch (healthchecks.io)

**Quién avisa:** healthchecks.io, por Telegram (su propio bot, no el del homelab) ·
**Configuración:** ruta `Watchdog` en [`apps/monitoring.yaml`](../../apps/monitoring.yaml)

## Qué significa

Alertmanager envía la alerta `Watchdog` (siempre activa) a healthchecks.io **cada minuto**. El
mensaje "homelab-alertmanager is DOWN" significa que lleva **más de 5 minutos sin llegar** ninguna.

Es decir: **el sistema de alertas del homelab no funciona**, y ninguna otra alerta te va a llegar
hasta que se arregle. Por eso este aviso viene de fuera de casa.

## Diagnóstico

Ve de lo más grande a lo más pequeño:

| # | Pregunta | Cómo comprobarlo | Si la respuesta es no |
|---|---|---|---|
| 1 | ¿Hay luz e internet en casa? | ¿Funciona el router? ¿Navegas desde el móvil con el wifi de casa? | Es eso. Al volver, el aviso se resuelve solo |
| 2 | ¿El PC (`nexcore`) está encendido y despierto? | Míralo; o desde la Pi: `ping -c 3 10.9.8.37` | Enciéndelo o despiértalo. Prometheus y Alertmanager viven ahí |
| 3 | ¿El nodo está `Ready`? | `kubectl get nodes` | `sudo systemctl status k3s-agent` en el PC |
| 4 | ¿Alertmanager está en marcha? | `kubectl -n monitoring get pods \| grep alertmanager` | `kubectl -n monitoring describe pod <pod>` (sección Events). ¿Falta algún Secret? |
| 5 | ¿Alertmanager consigue enviar el ping? | `kubectl -n monitoring logs alertmanager-monitoring-kube-prometheus-alertmanager-0 -c alertmanager \| grep -i healthchecks` | Errores de red: ¿el PC tiene internet? ¿La URL del Secret es correcta? |

## Verificación

- En healthchecks.io el check vuelve a **UP** (verde) y llega el aviso de recuperación.
- La columna **Last Ping** de healthchecks.io se actualiza cada minuto.

## Qué NO cubre

Si se cae la **Raspberry Pi**, el PC sigue enviando el Watchdog y healthchecks.io no avisa. Ese caso
lo cubre el propio Prometheus del PC: deja de leer las métricas de la Pi y salta `TargetDown`.

## Cambiar la URL de ping

```bash
read -rs HC_URL   # pega la URL nueva (no se ve) y pulsa Enter
kubectl -n monitoring create secret generic alertmanager-healthchecks \
  --from-file=url=/dev/stdin --dry-run=client -o yaml <<< "$HC_URL" | kubectl apply -f -
unset HC_URL
```
