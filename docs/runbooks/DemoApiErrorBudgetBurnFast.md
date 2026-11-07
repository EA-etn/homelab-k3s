# DemoApiErrorBudgetBurnFast

**Severidad:** critical · **Regla:** `platform/monitoring/demo-api-slo.yaml` · **SLOs:** [docs/slo.md](../slo.md)

## Qué significa

`demo-api` está gastando el presupuesto de errores de uno de sus SLOs (etiqueta `slo`) tan rápido
que, a este ritmo, **se agotará en menos de 5 días**: un 2 % en 1 hora o un 5 % en 6 horas.
Los usuarios ya están notando errores o lentitud **ahora mismo** (la ventana corta lo confirma).

| `slo` | Qué está fallando |
|---|---|
| `disponibilidad` | Demasiadas respuestas 5xx |
| `latencia` | Demasiadas respuestas tardan más de 100 ms |

## Diagnóstico

1. Abre el dashboard **demo-api · SLOs** y mira cuándo empezó a subir el burn rate.
2. **¿Coincide con un despliegue?** Es la causa más frecuente.
   ```bash
   kubectl -n demo-api get pods -o wide        # ¿pods con pocos minutos de vida?
   kubectl -n argocd get application demo-api
   ```
3. Abre el dashboard **demo-api**: ¿los errores o la lentitud vienen de un endpoint concreto?
   ¿De todos los pods o solo de uno?
4. Logs de la app:
   ```bash
   kubectl -n demo-api logs -l app.kubernetes.io/name=demo-api --since=30m --prefix | grep -v " 200 "
   ```
5. **Si es latencia:** ¿algún nodo está saturado? Dashboard **Node Exporter / USE Method / Node**.
   La Raspberry Pi tiene menos CPU que el portátil y, si se calienta, baja su frecuencia.
   ```bash
   kubectl top pods -n demo-api
   kubectl top nodes
   ```

## Mitigación

- **Empezó con un despliegue:** rollback con GitOps (ver [README](README.md#comandos-que-se-repiten)).
  Primero se recupera el servicio; después se investiga.
- **Un solo pod falla:** bórralo para que se cree otro: `kubectl -n demo-api delete pod <pod>`.
- **Nodo saturado:** más réplicas (`autoscaling.minReplicas` en `values-homelab.yaml`) o
  liberar recursos en ese nodo.

## Verificación

El burn rate de 1 hora baja de 14,4 en el dashboard y la alerta pasa a ✅ RESUELTA.
Mira cuánto presupuesto queda: si se ha gastado más del 20 %, escribe un postmortem.
