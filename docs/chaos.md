# Chaos engineering

Fallos provocados a propósito, con una hipótesis previa, para comprobar que el homelab aguanta y
avisa. Cada experimento sigue el mismo método: **estado estable → hipótesis → fallo → observación →
conclusión**.

| # | Experimento | Resultado |
|---|---|---|
| 0 | El nodo vuelve tras no estar disponible (`cordon` / `uncordon`) | ✅ El Descheduler devuelve un pod a su nodo |
| 1 | Matar un pod con tráfico | ✅ 300 peticiones, 0 fallidas |
| 2 | Desplegar una imagen que no existe | ✅ Sin impacto para los usuarios; aviso y vuelta atrás con `git revert` |
| 3 | Un 20 % de errores 5xx | ✅ Alerta crítica del SLO en ~21 minutos, como predice el cálculo |
| 4 | Apagar el PC y la Pi | Pendiente |

## 1 · Matar un pod con tráfico

- **Hipótesis:** si borro un pod de `demo-api` mientras recibe tráfico, no se pierde ninguna petición
  y no llega ninguna alerta.
- **Fallo:** 300 peticiones en 30 segundos y, en medio, `kubectl delete pod` del pod del PC.
- **Resultado:** ✅ 300 correctas, 0 fallidas. El sustituto se creó en el mismo nodo, respetando la
  regla de reparto obligatoria.
- **Por qué funciona:** el Service deja de enviar tráfico al pod que se apaga, el `preStop` da tiempo
  a Traefik a enterarse, y la otra réplica atiende mientras tanto.

## 2 · Desplegar una imagen que no existe

- **Hipótesis:** si se despliega una imagen inexistente, la app sigue funcionando con la versión
  anterior, ArgoCD muestra el problema, llega un aviso y se arregla con `git revert`.
- **Fallo:** un PR en `devsecops-pipeline` que cambia `image.tag` a `sha-0000000`.
- **Observación:**
  - El pod nuevo se queda en `ImagePullBackOff` (`sha-0000000: not found`) y los dos anteriores siguen
    `Running`, uno en cada nodo: `maxUnavailable: 0` impide sustituir la versión buena.
  - ArgoCD: `Synced` + `Progressing`.
  - A los ~10 minutos llega a Telegram 🟠 **TargetDown** ("33,33 % de los targets caídos"):
    Prometheus no puede leer las métricas del pod roto.
- **Recuperación:** *Revert* del PR en GitHub. El pod roto desaparece, ArgoCD vuelve a `Synced` +
  `Healthy` y el aviso se resuelve en **3 minutos**.
- **Resultado:** ✅ confirmada.
- **Hallazgos:**
  - ArgoCD tardó **~7 minutos** en aplicar el merge: revisa Git cada ~3 minutos, más margen y caché.
    En producción se configuraría un webhook de GitHub. Para no esperar:
    `kubectl -n argocd annotate application demo-api argocd.argoproj.io/refresh=hard --overwrite`.
  - La primera alerta no fue `KubePodNotReady` sino `TargetDown`: el monitoring detectó el fallo sin
    ninguna regla escrita para este caso.

## 3 · Un 20 % de errores 5xx

- **Hipótesis:** si el 20 % de las peticiones falla, en unos 25 minutos llega la alerta crítica de
  quema rápida del presupuesto, con su runbook, y se resuelve al quitar el fallo.
- **Fallo:** `chaos.errorRate: 0.2` en `values-homelab.yaml` (la app responde 500 a una fracción de
  las peticiones; `/health` y `/metrics` nunca fallan).
- **Observación:**
  - Un contador externo midió **406 fallos de unas 2.050 peticiones (19,8 %)** durante 34 minutos.
  - Los errores empezaron a las 22:53 y la alerta 🔴 **DemoApiErrorBudgetBurnFast** llegó a las
    **23:15**: unos 21 minutos. La disparó el par de ventanas **6 h / 30 min** (burn rate > 6×) antes
    que el par 1 h / 5 min (> 14,4×).
  - **Los pods siguieron `Running` y las probes en verde todo el tiempo.**
- **Recuperación:** *Revert* del PR; los errores pararon en cuanto se reiniciaron los pods.
- **Resultado:** ✅ confirmada.
- **Hallazgos:**
  - **Un pod `Running` no significa que los usuarios estén bien.** Kubernetes no vio ningún problema;
    lo detectó la alerta del SLO, que mide lo que viven los usuarios.
  - El aviso de resolución tarda unos 25 minutos: la ventana corta del par que disparó la alerta es de
    30 minutos. Es el precio de no alertar por picos de un segundo.
  - Con solo una semana de datos en Prometheus, la ventana "de 30 días" tiene pocas peticiones y cada
    error pesa más: el presupuesto bajó al ~60 %. Se normaliza al acumular el mes completo.
