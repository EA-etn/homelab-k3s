# DemoApiDown

**Severidad:** critical · **Regla:** `platform/monitoring/demo-api-alerts.yaml`

## Qué significa

Prometheus no consigue leer las métricas de **ninguna** réplica de `demo-api` desde hace 2 minutos.
Lo más probable es que la app esté caída para todos los usuarios.

Esta alerta existe porque los SLOs no ven una caída total: sin réplicas no hay métricas que medir.

## Diagnóstico

1. ¿Hay pods y en qué estado están?
   ```bash
   kubectl -n demo-api get pods -o wide
   ```
   | Estado | Siguiente paso |
   |---|---|
   | No hay pods | ¿Alguien borró el Deployment? Mira ArgoCD (paso 3) |
   | `Pending` | No hay nodo donde colocarlos: `kubectl -n demo-api describe pod <pod>` (sección Events) |
   | `CrashLoopBackOff` o `Error` | La app falla al arrancar: `kubectl -n demo-api logs <pod> --previous` |
   | `ImagePullBackOff` | No se puede descargar la imagen: ¿existe el tag en GHCR? ¿hay internet? |
   | `Running` pero `0/1` | La readiness probe falla: `kubectl -n demo-api describe pod <pod>` |
   | `Running 1/1` | La app funciona: el problema está en Prometheus (paso 4) |

2. ¿Los nodos están bien?
   ```bash
   kubectl get nodes
   ```
   Un nodo `NotReady` se lleva sus pods. Si los dos están caídos, también lo está la app.

3. ¿Qué dice ArgoCD?
   ```bash
   kubectl -n argocd get application demo-api
   ```
   Si está `Degraded` o `OutOfSync` justo después de un despliegue, el último cambio es el sospechoso.

4. Si los pods están bien, comprueba que Prometheus los ve: en Prometheus, **Status → Targets**,
   busca `demo-api`. Un error ahí apunta al ServiceMonitor o a la red, no a la app.

## Mitigación

- **Fallo tras un despliegue:** rollback con GitOps (ver [README](README.md#comandos-que-se-repiten)).
- **Nodo caído:** si es el portátil, enciéndelo o comprueba que no se ha suspendido. Los pods
  se reprogramarán en el otro nodo pasados unos minutos.
- **Imagen inexistente:** revisa el último commit del bot en `values-homelab.yaml`.

## Verificación

```bash
curl -s http://demo-api.home.arpa/health
```
Debe devolver `{"status":"ok"}` y la alerta pasa a ✅ RESUELTA en unos minutos.
