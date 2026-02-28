# M10 — WEEKLY REPORTER

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.


## Contexto
Relatório semanal do funil de outbound com métricas, insights AI e recomendações.

## Credenciais
```
CRM_BASE_URL=${CRM_BASE_URL}
CRM_API_KEY=${CRM_API_KEY}
RESEND_API_KEY=${RESEND_API_KEY}
```

## API do CRM

| Endpoint | Uso |
|----------|-----|
| `GET /v1/contacts?tenant=kosmos&per_page=100` | Leads KOSMOS |
| `GET /v1/contacts?tenant=oliveira-dev&per_page=100` | Leads Oliveira-dev |
| `GET /v1/contacts?cadence_status=in_sequence&per_page=100` | Em cadência |
| `GET /v1/contacts?cadence_status=replied&per_page=100` | Responderam |

Usar `page` pra paginar se necessário.

## Instruções

### STEP 1: Coletar dados por tenant

Buscar contatos com vários filtros pra montar o funil:

```bash
# Por classificação
curl -s "${CRM_BASE_URL}/v1/contacts?tenant=kosmos&classificacao=A&per_page=100" -H "Authorization: Bearer ${CRM_API_KEY}"
curl -s "${CRM_BASE_URL}/v1/contacts?tenant=kosmos&classificacao=B&per_page=100" -H "Authorization: Bearer ${CRM_API_KEY}"

# Por status de cadência
curl -s "${CRM_BASE_URL}/v1/contacts?tenant=kosmos&cadence_status=in_sequence&per_page=100" -H "Authorization: Bearer ${CRM_API_KEY}"
curl -s "${CRM_BASE_URL}/v1/contacts?tenant=kosmos&cadence_status=replied&per_page=100" -H "Authorization: Bearer ${CRM_API_KEY}"
```

Repetir pra oliveira-dev.

### STEP 2: Calcular métricas do funil

Separar por tenant:
- Topo: total leads, novos semana, por source
- Qualificação: A/B/C, taxa enriquecimento
- Outbound: em cadência, emails enviados, DMs
- Social selling: em warm_up, nurture
- Respostas: interested, not_interested, maybe
- Conversão: taxa funil completo

### STEP 3: Análise AI

- 3 insights da semana
- Comparação com semana anterior (se `/tmp/m10_history.json` existir)
- 3 recomendações acionáveis
- Gargalos do funil

### STEP 4: Relatório

```
╔══════════════════════════════════════════╗
║  WEEKLY REPORT — {data_inicio} a {fim}  ║
╚══════════════════════════════════════════╝

━━ KOSMOS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Leads: {n} | A:{n} B:{n} C:{n}
Em cadência: {n} | Warm_up: {n} | Nurture: {n}
Emails: {n} (open {%}, reply {%})
DMs: {n} (reply {%})
Interessados: {n} 🔥

━━ OLIVEIRA DEV ━━━━━━━━━━━━━━━━━━━━━━━━━
(mesma estrutura)

━━ 🧠 INSIGHTS ━━━━━━━━━━━━━━━━━━━━━━━━━━
1. ...  2. ...  3. ...

━━ ⚡ RECOMENDAÇÕES ━━━━━━━━━━━━━━━━━━━━━━
1. ...  2. ...  3. ...
```

Salve em `/tmp/m10_report_{YYYY-MM-DD}.log` e métricas em `/tmp/m10_history.json`

## Regras
- Roda sexta 18h
- Insights acionáveis, não genéricos
