# Alertas en Telegram

Prometheus evalúa las reglas, Alertmanager decide a quién avisar y Telegram entrega el mensaje
con un enlace al [runbook](runbooks/README.md) de la alerta.

```
Prometheus ──alerta──▶ Alertmanager ──agrupa, silencia, enruta──▶ Bot de Telegram ──▶ tu móvil
```

## Qué llega y qué no

| Alerta | ¿Mensaje? | Por qué |
|---|---|---|
| `critical` y `warning` | ✅ Sí, y otro ✅ cuando se resuelve | Requieren acción |
| `info` (p. ej. `DemoApiSingleNode`) | ❌ No | Informativas: se ven en Grafana y Alertmanager |
| `Watchdog` | ❌ No (va a healthchecks.io) | Está siempre activa: es la señal de vida del [dead man's switch](#dead-mans-switch) |

- **Agrupación:** alertas iguales del mismo namespace llegan en un solo mensaje (`group_by`).
- **Repetición:** si una alerta sigue activa, se recuerda cada 4 horas.
- **Inhibición:** si salta una `critical`, no se avisa también de la `warning` del mismo problema.
  Si se quema rápido el presupuesto de un SLO, no se avisa también de la quema lenta.

La configuración está en [`apps/monitoring.yaml`](../apps/monitoring.yaml) (sección `alertmanager`)
y el CI la valida con `amtool` ([`tests/alertmanager/`](../tests/alertmanager)).

## Puesta en marcha (una vez)

El token del bot es una credencial: **no va en Git ni se pega en ningún chat**. Vive en un
Secret de Kubernetes creado a mano, igual que la contraseña de Grafana.

1. **Crear el bot.** En Telegram, abre [@BotFather](https://t.me/BotFather), envía `/newbot`,
   elige un nombre y un usuario acabado en `bot`. Te dará un **token**.
2. **Escribir al bot.** Abre el chat con tu bot y envíale cualquier mensaje (por ejemplo `hola`).
   Un bot no puede escribirte hasta que tú le escribas primero.
3. **Guardar el token y obtener tu chat ID** (en el PC, sin que el token quede en el historial):
   ```bash
   read -rs -p "Token del bot: " TG_TOKEN; echo
   curl -s "https://api.telegram.org/bot${TG_TOKEN}/getUpdates" | grep -o '"chat":{"id":-\?[0-9]*' | head -1
   ```
   El número tras `"id":` es tu **chat ID**.
4. **Crear el Secret:**
   ```bash
   read -r -p "Chat ID: " TG_CHAT
   kubectl -n monitoring create secret generic alertmanager-telegram \
     --from-literal=bot-token="${TG_TOKEN}" --from-literal=chat-id="${TG_CHAT}"
   unset TG_TOKEN TG_CHAT
   ```

El Secret debe existir **antes** de desplegar la configuración: Alertmanager lo monta como archivos
y su pod no arranca sin él.

## Dead man's switch

**El problema:** Prometheus y Alertmanager corren en el PC. Si el PC se apaga (o se va la luz o
internet), las alertas se apagan con él y **no llega ningún aviso**.

**La solución:** Alertmanager envía cada minuto la alerta `Watchdog` (siempre activa) a
[healthchecks.io](https://healthchecks.io), un servicio **de fuera de casa**. Si deja de recibirla
durante 5 minutos, healthchecks.io avisa por Telegram. Qué hacer entonces:
[runbook](runbooks/DeadMansSwitch.md).

```
Alertmanager ──Watchdog cada minuto──▶ healthchecks.io ──¿5 min sin señal?──▶ Telegram
```

| Si cae… | ¿Quién avisa? |
|---|---|
| El PC, la luz o internet de casa | healthchecks.io (deja de recibir el Watchdog) |
| Alertmanager o Prometheus | healthchecks.io |
| La Raspberry Pi | Prometheus, desde el PC (`TargetDown`) |

**Puesta en marcha (una vez):**

1. En healthchecks.io: **Add Check** con *Period* 1 minuto y *Grace Time* 5 minutos. En
   **Integrations**, conecta Telegram (healthchecks usa su propio bot). En la descripción del
   check, pega el enlace al [runbook](runbooks/DeadMansSwitch.md).
2. Copia la **Ping URL** del check. Es una credencial: quien la tenga puede enviar señales falsas.
3. Crea el Secret (en el PC, sin que la URL quede en el historial):
   ```bash
   read -rs HC_URL   # pega la URL (no se ve) y pulsa Enter
   kubectl -n monitoring create secret generic alertmanager-healthchecks --from-file=url=/dev/stdin <<< "$HC_URL"
   unset HC_URL
   ```

Como el de Telegram, este Secret debe existir **antes** de desplegar la configuración.

## Probarlo

Envía una alerta de prueba directamente a Alertmanager:

```bash
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-alertmanager 9093 &
curl -s -XPOST localhost:9093/api/v2/alerts -H 'Content-Type: application/json' -d '[{
  "labels": {"alertname": "PruebaTelegram", "severity": "warning", "namespace": "monitoring"},
  "annotations": {"summary": "Alerta de prueba", "description": "Si lees esto, las alertas llegan al móvil.",
                  "runbook_url": "https://github.com/EA-etn/homelab-k3s/blob/main/docs/runbooks/README.md"}
}]'
```

En unos 30 segundos (`group_wait`) llega el mensaje 🟠 AVISO. La alerta caduca sola a los
5 minutos (`resolve_timeout`) y entonces llega ✅ RESUELTA.

## Silenciar una alerta (mantenimiento)

Antes de apagar un nodo a propósito, crea un **silencio** en la interfaz de Alertmanager
(`localhost:9093` con el port-forward anterior → **New Silence**), con un motivo y una duración.
Así no recibes alertas de algo planificado.

## Cambiar el token

```bash
kubectl -n monitoring delete secret alertmanager-telegram
# y repetir los pasos 3 y 4
```
