# DemoApiSingleNode

**Severidad:** info (no envía mensaje; se ve en Grafana y Alertmanager) · **Regla:** `platform/monitoring/demo-api-alerts.yaml`

## Qué significa

Todas las réplicas de `demo-api` llevan 15 minutos en el **mismo nodo**. La app funciona, pero
si ese nodo cae se queda sin servicio hasta que Kubernetes reprograma los pods en el otro.

## Diagnóstico

```bash
kubectl get nodes
kubectl -n demo-api get pods -o wide
```

- **El otro nodo está `NotReady`:** es la causa. Normalmente es el portátil apagado o suspendido.
- **Los dos nodos están `Ready`:** el chart usa `topologySpreadConstraints` con
  `whenUnsatisfiable: ScheduleAnyway`, una preferencia y no una obligación. Si un nodo estuvo
  caído, los pods se quedan donde se movieron y Kubernetes no los reparte solo.

## Mitigación

Con los dos nodos `Ready`, borra uno de los pods: el nuevo se colocará en el otro nodo.
```bash
kubectl -n demo-api delete pod <pod>
```
Gracias al apagado limpio y al PDB, no se pierde ninguna petición.

## Verificación

`kubectl -n demo-api get pods -o wide` muestra réplicas en `devops-lab` y en `nexcore`.
