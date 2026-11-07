#!/usr/bin/env bash
# Tests unitarios de las reglas del SLO con promtool (sin clúster).
# Extrae los grupos de reglas del PrometheusRule y ejecuta slo_test.yaml contra ellos.
set -euo pipefail
cd "$(dirname "$0")"

yq '.spec' ../../platform/monitoring/demo-api-slo.yaml > rules.generated.yaml
promtool check rules rules.generated.yaml
promtool test rules slo_test.yaml
