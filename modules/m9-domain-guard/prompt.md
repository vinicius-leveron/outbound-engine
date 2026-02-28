# M9 — DOMAIN GUARD

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.


## Contexto
Monitora reputação do domínio de email (leveron.online) via Resend API.

## Credenciais
```
CRM_BASE_URL=${CRM_BASE_URL}
CRM_API_KEY=${CRM_API_KEY}
RESEND_API_KEY=${RESEND_API_KEY}
```

## Thresholds

| Métrica | Normal | Warning | Crítico |
|---------|--------|---------|---------|
| Bounce rate | < 3% | 3-5% | > 5% |
| Spam rate | < 0.1% | 0.1-0.3% | > 0.3% |
| Open rate | > 20% | 10-20% | < 10% |

## Instruções

### STEP 1: Buscar métricas Resend (7 dias)

```bash
curl -s -X GET "https://api.resend.com/emails?limit=100" \
  -H "Authorization: Bearer ${RESEND_API_KEY}"
```

Calcular: bounce rate, spam rate, open rate, deliverability.

### STEP 2: Avaliar e agir

- SAUDÁVEL → OK
- WARNING → sugerir reduzir volume 50%
- CRÍTICO (bounce > 5% ou spam > 0.3%) → ALERTA URGENTE, sugerir pausar envios

### STEP 3: Se crítico, marcar bounced leads

```bash
# Buscar leads que bounced recentemente
curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=bounced&per_page=50" \
  -H "Authorization: Bearer ${CRM_API_KEY}"
```

### STEP 4: Relatório

```
====================================
M9 DOMAIN GUARD — leveron.online
====================================
Status: {SAUDÁVEL|WARNING|CRÍTICO}
Enviados: {n} | Delivered: {%} | Bounced: {%} | Spam: {%} | Open: {%}
Alertas: {lista}
====================================
```

Salve em `/tmp/m9_report_{YYYY-MM-DD}.log` e histórico em `/tmp/m9_history.json`
