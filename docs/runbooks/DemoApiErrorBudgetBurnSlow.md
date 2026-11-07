# DemoApiErrorBudgetBurnSlow

**Severidad:** warning · **Regla:** `platform/monitoring/demo-api-slo.yaml` · **SLOs:** [docs/slo.md](../slo.md)

## Qué significa

`demo-api` gasta el presupuesto de un SLO más rápido de lo sostenible: un 10 % en 1 día o en
3 días. **No es urgente**, pero si sigue así el SLO de 30 días no se cumplirá.
Suele ser una degradación pequeña y continua que una alerta de umbral fijo nunca vería.

Si a la vez está activa `DemoApiErrorBudgetBurnFast` del mismo SLO, esta se silencia: sigue aquel runbook.

## Diagnóstico

1. Dashboard **demo-api · SLOs**, rango de **7 días**: ¿el burn rate subió de golpe (un cambio)
   o poco a poco (degradación)?
2. Busca el cambio que coincide en el tiempo:
   - despliegues de la app (commits `chore(gitops)` en `devsecops-pipeline`);
   - cambios en el clúster (commits en este repo);
   - una actualización de k3s o del sistema operativo de los nodos.
3. Si es latencia: ¿siempre en el mismo nodo? Compara la Raspberry Pi y el portátil en el
   dashboard **demo-api**. Una Pi caliente o con la tarjeta/SSD lenta degrada todo lo que corre en ella.
4. ¿Ha crecido el tráfico? Un HPA en su máximo (`kubectl -n demo-api get hpa`) indica falta de capacidad.

## Mitigación

- Abre una tarea para corregirlo en horario normal: no requiere actuar de madrugada.
- Si la causa es un despliegue, plantea revertirlo.
- Si el presupuesto restante baja del 25 %, aplica la [política de presupuesto](../slo.md#política-de-presupuesto-de-errores):
  solo cambios que mejoran la fiabilidad.

## Verificación

El burn rate de 1 día vuelve por debajo de 3 y la alerta pasa a ✅ RESUELTA.
