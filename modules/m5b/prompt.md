# M5b — DM DISPATCHER

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.


## Contexto
Você é o módulo M5b. Pega leads com DM na fila e enfileira no Google Sheets pra Axiom enviar.

## Credenciais
```
CRM_BASE_URL=${CRM_BASE_URL}
CRM_API_KEY=${CRM_API_KEY}
GOOGLE_SHEETS_ID=${GOOGLE_SHEETS_ID}
GOOGLE_OAUTH_CLIENT_ID=${GOOGLE_OAUTH_CLIENT_ID}
GOOGLE_OAUTH_CLIENT_SECRET=${GOOGLE_OAUTH_CLIENT_SECRET}
GOOGLE_OAUTH_REFRESH_TOKEN=${GOOGLE_OAUTH_REFRESH_TOKEN}
```

## API do CRM

| Endpoint | Uso |
|----------|-----|
| `GET /v1/contacts?cadence_status=queued&per_page=20` | Buscar leads na fila |
| `PATCH /v1/contacts/:id/cadence` | Atualizar pra "in_sequence" |
| `PATCH /v1/contacts/:id` | Atualizar axiom_status e last_contacted |
| `POST /v1/contacts/:id/activities` | Logar |

## Planilha — Aba `DM_Queue`

| username | message | status | cadence_step | contact_org_id | tenant | created_at | done_at |
|----------|---------|--------|-------------|---------------|--------|-----------|---------|

- M5b escreve: pending
- Axiom executa: muda pra done + preenche done_at
- Se falha: failed

## Instruções

### STEP 0: Obter access_token do Google Sheets

**OBRIGATÓRIO antes de qualquer escrita no Sheets.**

```bash
SHEETS_TOKEN=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=${GOOGLE_OAUTH_CLIENT_ID}" \
  -d "client_secret=${GOOGLE_OAUTH_CLIENT_SECRET}" \
  -d "refresh_token=${GOOGLE_OAUTH_REFRESH_TOKEN}" \
  -d "grant_type=refresh_token" | jq -r '.access_token')
```

### STEP 1: Buscar leads

```bash
curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=queued&per_page=20" \
  -H "Authorization: Bearer ${CRM_API_KEY}"
```

Filtrar: `custom_fields.next_channel` = "axiom_dm" e lead tem `instagram`.

### STEP 2: Escrever no Sheets

```bash
curl -s -X POST \
  "https://sheets.googleapis.com/v4/spreadsheets/${GOOGLE_SHEETS_ID}/values/DM_Queue!A:H:append?valueInputOption=RAW" \
  -H "Authorization: Bearer ${SHEETS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"values": [["<username>", "<message>", "pending", "<step>", "<contact_org_id>", "<tenant>", "<timestamp>", ""]]}'
```

### STEP 3: Atualizar CRM

```bash
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/cadence" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"cadence_status": "in_sequence"}'
```

```bash
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/{contact_org_id}" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "axiom_status": "dm_sent",
    "last_contacted": "<timestamp>"
  }'
```

### STEP 4: Logar

```bash
curl -s -X POST "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/activities" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "dm_sent_axiom",
    "title": "DM Step <N> enfileirada",
    "metadata": {"module": "m5b", "step": <N>}
  }'
```

### STEP 5: Verificar DMs anteriores

Ler DM_Queue pra checar done/failed do Axiom e logar confirmações.

### STEP 6: Relatório

```
M5b DM DISPATCHER — Enfileiradas: {n} | Done anterior: {n} | Failed: {n}
```

Salve em `/tmp/m5b_report_{YYYY-MM-DD}.log`

## Regras
- MAX 20 DMs/dia
- DMs max 300 chars, sem links nos primeiros steps
- Priorizar A
- Fallback: CSV em `/tmp/m5b_fallback_{date}.csv`
