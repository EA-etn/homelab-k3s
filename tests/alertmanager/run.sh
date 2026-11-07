#!/usr/bin/env bash
# Valida la configuración de Alertmanager definida en apps/monitoring.yaml (sin clúster):
# sintaxis, a qué receptor va cada alerta y cómo queda el mensaje de Telegram.
set -euo pipefail
cd "$(dirname "$0")"

values='.spec.source.helm.valuesObject.alertmanager'
yq "${values}.config" ../../apps/monitoring.yaml > alertmanager.generated.yaml
yq -r "${values}.templateFiles.\"telegram.tmpl\"" ../../apps/monitoring.yaml > telegram.generated.tmpl

amtool check-config alertmanager.generated.yaml

# routes test: alerta (etiquetas) → receptor esperado
expect_route() {
  local expected=$1; shift
  amtool config routes test --config.file=alertmanager.generated.yaml --verify.receivers="${expected}" "$@" >/dev/null \
    || { echo "FALLO: $* debería ir a ${expected}"; exit 1; }
  echo "ok: $* → ${expected}"
}
expect_route telegram alertname=DemoApiErrorBudgetBurnFast severity=critical slo=disponibilidad
expect_route telegram alertname=DemoApiDown severity=critical
expect_route telegram alertname=KubePodCrashLooping severity=warning namespace=demo-api
expect_route null alertname=Watchdog severity=none
expect_route null alertname=DemoApiSingleNode severity=info

# Mensaje de ejemplo (una alerta activa y una resuelta)
echo "--- Mensaje de Telegram de ejemplo:"
amtool template render --template.glob=telegram.generated.tmpl \
  --template.data=alerts.json --template.text='{{ template "telegram.homelab" . }}'
