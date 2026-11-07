# Runbooks

Un runbook responde a una pregunta: **acaba de saltar esta alerta, ¿qué hago?**
Cada alerta propia lleva un enlace a su runbook (`runbook_url`) y el mensaje de Telegram lo incluye.

| Alerta | Severidad | Runbook |
|---|---|---|
| `DemoApiDown` | critical | [DemoApiDown](DemoApiDown.md) |
| `DemoApiErrorBudgetBurnFast` | critical | [DemoApiErrorBudgetBurnFast](DemoApiErrorBudgetBurnFast.md) |
| `DemoApiErrorBudgetBurnSlow` | warning | [DemoApiErrorBudgetBurnSlow](DemoApiErrorBudgetBurnSlow.md) |
| `DemoApiErrorBudgetExhausted` | warning | [DemoApiErrorBudgetExhausted](DemoApiErrorBudgetExhausted.md) |
| `DemoApiSingleNode` | info | [DemoApiSingleNode](DemoApiSingleNode.md) |

Las alertas que trae kube-prometheus-stack (`KubePodCrashLooping`, `NodeFilesystemSpaceFillingUp`…)
enlazan a los runbooks oficiales en [runbooks.prometheus-operator.dev](https://runbooks.prometheus-operator.dev).

## Cómo responder a cualquier alerta

1. **Reconocer:** lee el mensaje y abre el runbook.
2. **Evaluar el impacto:** ¿los usuarios lo notan? Mira el dashboard **demo-api · SLOs**.
3. **Mitigar primero, investigar después:** volver a la versión anterior suele ser más rápido que
   arreglar el fallo en caliente.
4. **Confirmar:** espera el mensaje ✅ RESUELTA de Telegram.
5. **Aprender:** si se gastó una parte importante del presupuesto, escribe un postmortem sin culpables
   (qué pasó, por qué y qué cambia para que no se repita).

## Comandos que se repiten

```bash
# Estado de la app y en qué nodo está cada réplica
kubectl -n demo-api get pods -o wide

# Por qué un pod no arranca o se reinicia
kubectl -n demo-api describe pod <pod>
kubectl -n demo-api logs <pod> --previous

# Últimos eventos del namespace
kubectl -n demo-api get events --sort-by=.lastTimestamp | tail -20

# Qué versión está desplegada y si ArgoCD está sincronizado
kubectl -n argocd get application demo-api
kubectl -n demo-api get deploy demo-api -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

**Volver a la versión anterior (rollback con GitOps):** en el repo `devsecops-pipeline`, revierte el
último commit del bot (`chore(gitops): desplegar sha-…`) con `git revert` y súbelo en un PR.
ArgoCD desplegará la imagen anterior. No uses `kubectl rollout undo`: ArgoCD lo revertiría (`selfHeal`).
