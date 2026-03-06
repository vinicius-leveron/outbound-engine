# M5b — DM DISPATCHER

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.


## Contexto
Você é o módulo M5b. Pega leads com DM na fila e enfileira no Google Sheets pra Axiom enviar.

## Credenciais
```
CRM_BASE_URL=${CRM_BASE_URL}
CRM_API_KEY=${CRM_API_KEY}
GOOGLE_SHEETS_ID=1cE5LT-gW5F6b-TvDrA5MtIafO7uY1co-zSYMTuUzawk
GOOGLE_SHEETS_API_KEY=AIzaSyDDTGKRUuibxHFXPHl1ja7eRdPaUI6qGhc
```

## API do CRM

| Endpoint | Uso |
|----------|-----|
| `GET /v1/contacts?cadence_status=queued&per_page=20` | Buscar leads na fila |
| `PATCH /v1/contacts/:id/cadence` | Atualizar pra "in_sequence" |
| `PATCH /v1/contacts/:id` | Atualizar axiom_status e last_contacted |
| `POST /v1/contacts/:id/activities` | Logar |

## Planilha — Aba `DM_Queue`

| Coluna | Campo | Uso |
|--------|-------|-----|
| A | username | @ do lead (sem @) |
| B | message | Copy Step 2 (opener) |
| C | follow-up | Copy Step 4 (follow-up) |
| D | status | pending / sent / failed |
| E | step | 2 ou 4 |
| F | contact_org_id | ID do lead no CRM |
| G | tenant | kosmos / oliveira-dev |
| H | timestamp | Data de enfileiramento |
| I | sent_at | Data de envio |

**Fluxo:**
- M4 escreve na fila com status `pending`
- M5b lê fila, dispara Axiom, marca `sent` + preenche `sent_at`
- Se falha: marca `failed`

**Lógica de leitura:**
- Se `step=2` → envia conteúdo da coluna B (message)
- Se `step=4` → envia conteúdo da coluna C (follow-up)

## Instruções

### STEP 1: Buscar leads

```bash
curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=queued&per_page=20" \
  -H "Authorization: Bearer ${CRM_API_KEY}"
```

Filtrar: `custom_fields.next_channel` = "axiom_dm" e lead tem `instagram`.

### STEP 2: Ler fila do Sheets (DM_Queue com status=pending)

```bash
# Obter access token OAuth
SHEETS_TOKEN=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=${GOOGLE_OAUTH_CLIENT_ID}" \
  -d "client_secret=${GOOGLE_OAUTH_CLIENT_SECRET}" \
  -d "refresh_token=${GOOGLE_OAUTH_REFRESH_TOKEN}" \
  -d "grant_type=refresh_token" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

# Ler toda a aba DM_Queue
curl -s "https://sheets.googleapis.com/v4/spreadsheets/${GOOGLE_SHEETS_ID}/values/DM_Queue!A:I" \
  -H "Authorization: Bearer ${SHEETS_TOKEN}"
```

**Para cada linha com status=pending:**
1. Ler `step` (coluna E)
2. Se `step=2` → usar `message` (coluna B)
3. Se `step=4` → usar `follow-up` (coluna C)
4. Disparar Axiom com o conteúdo correto
5. Marcar `status=sent` (coluna D) e preencher `sent_at` (coluna I)

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
