# DemoApiErrorBudgetExhausted

**Severidad:** warning · **Regla:** `platform/monitoring/demo-api-slo.yaml` · **SLOs:** [docs/slo.md](../slo.md)

## Qué significa

El presupuesto de errores de 30 días de un SLO está gastado: **el SLO está incumplido**.
No describe un fallo actual (para eso están las alertas de burn rate), sino el balance del mes.

## Qué hacer

Aplicar la [política de presupuesto de errores](../slo.md#política-de-presupuesto-de-errores):

1. **Congelar los cambios no urgentes** en `demo-api` y en el clúster hasta que el presupuesto se
   recupere (los fallos antiguos van saliendo de la ventana de 30 días).
2. **Postmortem sin culpables** de los incidentes que gastaron el presupuesto:
   - qué pasó y cuándo (dashboard **demo-api · SLOs**, rango de 30 días);
   - por qué no se detectó o mitigó antes;
   - acciones concretas, con responsable, para que no se repita.
3. Dedicar el trabajo a **fiabilidad**: más réplicas, mejores tests E2E, alertas más tempranas.
4. Si el SLO se incumple a menudo sin un fallo claro, quizá el objetivo no es realista para esta
   infraestructura. Revisarlo es válido, pero debe ser una decisión explícita y documentada.

## Verificación

El presupuesto restante vuelve a ser positivo y la alerta pasa a ✅ RESUELTA.
