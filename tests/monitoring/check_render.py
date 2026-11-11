"""Comprueba el render real de kube-prometheus-stack con los valores de apps/monitoring.yaml.

Protege lo que un error de edición podría borrar sin que nada falle: el Ingress de Grafana,
su contraseña desde un Secret externo, el Secret de Telegram de Alertmanager y dónde corre cada pieza.
Uso: python3 check_render.py <manifiestos-renderizados.yaml>
"""
import sys

import yaml

docs = [d for d in yaml.safe_load_all(open(sys.argv[1])) if d]
by_kind = {}
for d in docs:
    by_kind.setdefault(d["kind"], []).append(d)

fails = []


def check(cond, msg):
    print(("ok: " if cond else "FALLO: ") + msg)
    if not cond:
        fails.append(msg)


def find(kind, name_part):
    return [d for d in by_kind.get(kind, []) if name_part in d["metadata"]["name"]]


ing = find("Ingress", "grafana")
hosts = [r.get("host") for i in ing for r in i["spec"].get("rules", [])]
check("grafana.home.arpa" in hosts, "Ingress de Grafana con host grafana.home.arpa")

graf = find("Deployment", "grafana")
graf_yaml = yaml.safe_dump(graf)
check("grafana-admin" in graf_yaml, "Grafana lee la contraseña de admin del Secret grafana-admin")
check(bool(graf) and graf[0]["spec"]["template"]["spec"].get("nodeSelector") == {"homelab/role": "worker"},
      "Grafana corre en el worker")

am = by_kind.get("Alertmanager", [])
check(bool(am) and "alertmanager-telegram" in am[0]["spec"].get("secrets", []),
      "Alertmanager monta el Secret alertmanager-telegram")
check(bool(am) and "alertmanager-healthchecks" in am[0]["spec"].get("secrets", []),
      "Alertmanager monta el Secret alertmanager-healthchecks (dead man's switch)")

prom = by_kind.get("Prometheus", [])
check(bool(prom) and prom[0]["spec"].get("retention") == "30d", "Prometheus guarda 30 días (ventana del SLO)")

ksm = find("Deployment", "kube-state-metrics")
if ksm:  # en el CI se renderiza el chart completo
    check(ksm[0]["spec"]["template"]["spec"].get("nodeSelector") == {"homelab/role": "worker"},
          "kube-state-metrics corre en el worker")

sys.exit(1 if fails else 0)
