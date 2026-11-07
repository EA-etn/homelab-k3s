#!/usr/bin/env bash
# Renderiza kube-prometheus-stack con los valores de apps/monitoring.yaml (como hace ArgoCD)
# y comprueba que el resultado contiene lo importante. Uso: tests/monitoring/run.sh
set -euo pipefail
cd "$(dirname "$0")"

read -r chart version repo < <(python3 -c '
import yaml
s = yaml.safe_load(open("../../apps/monitoring.yaml"))["spec"]["source"]
print(s["chart"], s["targetRevision"], s["repoURL"])
yaml.safe_dump(s["helm"]["valuesObject"], open("values.generated.yaml", "w"))
')

# CHART_DIR permite usar una copia local del chart (sin acceso al repositorio de Helm)
if [[ -z "${CHART_DIR:-}" ]]; then
  helm repo add prometheus-community "${repo}" >/dev/null
  helm repo update prometheus-community >/dev/null
  CHART_DIR="prometheus-community/${chart}"
fi

# shellcheck disable=SC2086 # EXTRA_HELM_ARGS se separa en argumentos a propósito
helm template monitoring "${CHART_DIR}" --version "${version}" -n monitoring \
  -f values.generated.yaml ${EXTRA_HELM_ARGS:-} > rendered.generated.yaml
python3 check_render.py rendered.generated.yaml
