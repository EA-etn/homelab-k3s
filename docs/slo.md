# SLOs de demo-api

Qué prometemos sobre `demo-api`, cómo se mide y qué hacemos cuando no se cumple.

| Archivo | Contenido |
|---|---|
| [`platform/monitoring/demo-api-slo.yaml`](../platform/monitoring/demo-api-slo.yaml) | SLIs, presupuesto de errores y alertas (PrometheusRule) |
| [`platform/monitoring/demo-api-slo-dashboard.yaml`](../platform/monitoring/demo-api-slo-dashboard.yaml) | Dashboard de Grafana **demo-api · SLOs** |
| [`platform/monitoring/synthetic-traffic.yaml`](../platform/monitoring/synthetic-traffic.yaml) | Tráfico sintético para que el SLI siempre tenga datos |
| [`tests/slo/`](../tests/slo) | Tests unitarios de las reglas con `promtool` (se ejecutan en el CI) |
| [`docs/runbooks/`](runbooks/README.md) | Qué hacer cuando salta cada alerta |
| [`docs/alerting.md`](alerting.md) | Cómo llegan las alertas a Telegram |

## Conceptos en 30 segundos

| Término | Qué es | En demo-api |
|---|---|---|
| **SLI** (indicador) | Porcentaje de eventos buenos sobre el total | Peticiones sin 5xx / todas las peticiones |
| **SLO** (objetivo) | El valor que se quiere alcanzar en una ventana de tiempo | 99,5 % en 30 días |
| **Presupuesto de errores** | Lo que se permite fallar: 100 % − SLO | 0,5 % de las peticiones |
| **Burn rate** | A qué velocidad se gasta el presupuesto | 1 = se gasta justo en 30 días |

Un SLO del 100 % no existe: cada cambio tiene riesgo y no desplegar nunca también es un fallo.
El presupuesto convierte la fiabilidad en algo que se puede **gastar**: mientras quede, se
despliega con normalidad; cuando se agota, la prioridad pasa a ser la estabilidad.

## Los SLOs

| SLO | Petición buena | Objetivo | Ventana | Presupuesto (con tráfico constante) |
|---|---|---|---|---|
| **Disponibilidad** | Respuesta que no es 5xx | 99,5 % | 30 días | 216 min de caída total |
| **Latencia** | Respuesta servida en menos de 100 ms | 99 % | 30 días | 1 % de peticiones lentas (432 min) |

**Decisiones:**

- **Se miden peticiones de usuario.** La app excluye `/health` y `/metrics` de sus métricas:
  las probes de Kubernetes y Prometheus no son usuarios.
- **Los 4xx no son errores del servicio.** Un 404 es un fallo del cliente.
- **100 ms** es un límite del histograma de la app (buckets de 0,1 s, 0,5 s y 1 s): el SLI se
  calcula exacto, sin estimar percentiles.
- **99,5 % y no 99,9 %:** el homelab tiene un solo control plane en una Raspberry Pi y se
  apaga para mantenimiento. Un objetivo debe reflejar lo que la infraestructura puede dar.

## Tráfico sintético

Sin usuarios no hay SLI: con 0 peticiones, el porcentaje de peticiones buenas no existe.
El Deployment `synthetic-traffic` hace 2 peticiones por segundo a `/` y `/info` **a través
de Traefik** con el host `demo-api.home.arpa`, igual que un navegador. Así el SLI incluye
el Ingress, el Service y los pods.

## Alertas: multi-ventana y multi-burn-rate

Una alerta del tipo "más de un 5 % de errores durante 5 minutos" despierta por picos que no
ponen en riesgo el SLO y no avisa de una degradación pequeña que dura días. Las alertas por
burn rate preguntan otra cosa: **¿a este ritmo vamos a incumplir el SLO?**

| Alerta | Condición | Gasto del presupuesto | Severidad |
|---|---|---|---|
| `DemoApiErrorBudgetBurnFast` | burn rate > 14,4 en 1 h **y** en 5 min | 2 % en 1 hora (se agota en ~2 días) | critical |
| | burn rate > 6 en 6 h **y** en 30 min | 5 % en 6 horas (se agota en 5 días) | critical |
| `DemoApiErrorBudgetBurnSlow` | burn rate > 3 en 1 día **y** en 2 h | 10 % en 1 día | warning |
| | burn rate > 1 en 3 días **y** en 6 h | 10 % en 3 días | warning |
| `DemoApiErrorBudgetExhausted` | presupuesto ≤ 0 durante 15 min | SLO incumplido | warning |

La ventana larga mide si el gasto es significativo; la corta confirma que **sigue ocurriendo
ahora**, para que la alerta se resuelva poco después de arreglar el problema. Los umbrales
son los del capítulo 5 del [Google SRE Workbook](https://sre.google/workbook/alerting-on-slos/).

Estas alertas sustituyen a `DemoApiHighErrorRate` y `DemoApiSlow`, que eran de umbral fijo.

### Lo que el SLO no ve

Las métricas las publica la propia app. **Si no queda ninguna réplica, no hay métricas** y el
SLI se queda sin datos en vez de bajar. Para eso sigue existiendo `DemoApiDown`
(`demo-api-alerts.yaml`). Medir en Traefik o con un sondeo externo cerraría ese hueco.

## Política de presupuesto de errores

| Presupuesto restante | Qué hacemos |
|---|---|
| > 50 % | Desplegar con normalidad |
| 25–50 % | Revisar qué lo consume antes de cambios arriesgados |
| < 25 % | Solo cambios que mejoran la fiabilidad |
| ≤ 0 % | Congelar cambios no urgentes hasta recuperar presupuesto; escribir un postmortem |

## Cómo se calcula

1. Cada 30 s se guardan las peticiones totales y las malas por segundo (ventana de 5 min):
   `slo:sli_total:rate5m` y `slo:sli_errors:rate5m`.
2. Para cada ventana (30 min … 3 días) se suman esas tasas: `slo:sli_error:ratio_rate1h`, etc.
   Sumar tasas, en vez de promediar porcentajes, da más peso a los momentos con más tráfico.
3. Cada 5 min se calcula la ventana de 30 días y el presupuesto restante:
   `slo:error_budget:remaining_ratio = 1 − error_30d / (1 − objetivo)`.

Prometheus guarda 30 días de datos (`retention: 30d` en `apps/monitoring.yaml`, con
`retentionSize: 8GB` como límite). Hasta que pasen 30 días desde la instalación, la ventana
del SLO solo incluye los datos que hay.

## Tests

```bash
tests/slo/run.sh   # necesita promtool y yq
```

Cada escenario simula métricas y comprueba qué alertas saltan: tráfico sano, 20 % de errores,
respuestas lentas, 2 % de errores sostenido y ausencia de tráfico. El CI los ejecuta en cada
pull request.
