# C3 — DAILY BRIEFING

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.


## Contexto
Resumo diário do CRM pro Vinícius: leads, pendências, alertas, métricas de ontem.

## Credenciais
```
CRM_BASE_URL=${CRM_BASE_URL}
CRM_API_KEY=${CRM_API_KEY}
```

## API do CRM

| Endpoint | Uso |
|----------|-----|
| `GET /v1/contacts?cadence_status=<status>&per_page=100` | Contagem por status |
| `GET /v1/contacts?classificacao=A&per_page=100` | Leads A |
| `GET /v1/contacts?cadence_status=replied&per_page=50` | Leads que responderam |
| `GET /v1/contacts?cadence_status=new&per_page=50` | Aguardando scoring |

## Instruções

### STEP 1: Coletar dados

```bash
# Pipeline por status
curl -s "${CRM_BASE_URL}/v1/contacts?cadence_status=new&per_page=100" -H "Authorization: Bearer ${CRM_API_KEY}"
curl -s "${CRM_BASE_URL}/v1/contacts?cadence_status=in_sequence&per_page=100" -H "Authorization: Bearer ${CRM_API_KEY}"
curl -s "${CRM_BASE_URL}/v1/contacts?cadence_status=replied&per_page=100" -H "Authorization: Bearer ${CRM_API_KEY}"
curl -s "${CRM_BASE_URL}/v1/contacts?cadence_status=ready&per_page=100" -H "Authorization: Bearer ${CRM_API_KEY}"

# Por classificação
curl -s "${CRM_BASE_URL}/v1/contacts?classificacao=A&per_page=100" -H "Authorization: Bearer ${CRM_API_KEY}"
curl -s "${CRM_BASE_URL}/v1/contacts?classificacao=B&per_page=100" -H "Authorization: Bearer ${CRM_API_KEY}"
```

### STEP 2: Métricas de ontem

Filtrar por `created_at` ou `last_contacted` nas últimas 24h (se a API suportar, senão estimar pelos dados).

### STEP 3: Itens de ação

1. Leads "replied" com interesse → responder manualmente
2. Leads "replied" com pergunta → responder
3. Alertas M9 (ler `/tmp/m9_report_*.log` mais recente)
4. Leads A novos
5. Módulos com erro

### STEP 4: Briefing

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
☀️  BOM DIA, VINÍCIUS! — {data}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 ONTEM:
  Leads novos: {n} | Classificados: {n}
  Emails: {n} | DMs: {n}
  Respostas: {n} | Interessados: {n} 🔥

📋 PIPELINE:
  A: {n} | B: {n} | Em cadência: {n}
  Warm_up: {n} | Aguardando score: {n}

🎯 AÇÃO:
  {lista de ações necessárias}

💡 {insight do dia}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Salve em `/tmp/c3_briefing_{YYYY-MM-DD}.log`

## Regras
- Roda 8h, max 40 linhas
- Se nenhuma ação: "Tudo no piloto automático ✅"
