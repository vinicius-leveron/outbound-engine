# M6 — EVENT TRACKER

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.


## Contexto
Você é o módulo M6. Faz polling de eventos (email opens/clicks/bounces via Resend, DMs via Sheets) e classifica respostas com AI.

## Credenciais
```
CRM_BASE_URL=${CRM_BASE_URL}
CRM_API_KEY=${CRM_API_KEY}
RESEND_API_KEY=${RESEND_API_KEY}
GOOGLE_SHEETS_ID=1cE5LT-gW5F6b-TvDrA5MtIafO7uY1co-zSYMTuUzawk
GOOGLE_SHEETS_API_KEY=AIzaSyDDTGKRUuibxHFXPHl1ja7eRdPaUI6qGhc
```

## API do CRM

| Endpoint | Uso |
|----------|-----|
| `GET /v1/contacts?cadence_status=in_sequence&per_page=100` | Leads em cadência ativa |
| `PATCH /v1/contacts/:id/cadence` | Mudar status (replied, bounced, etc.) |
| `PATCH /v1/contacts/:id` | Atualizar score_engagement, custom_fields |
| `POST /v1/contacts/:id/activities` | Logar eventos |

## Instruções

### STEP 1: Polling Resend (email events)

```bash
curl -s -X GET "https://api.resend.com/emails" \
  -H "Authorization: Bearer ${RESEND_API_KEY}"
```

Usar tags pra vincular ao contact_org_id. Eventos:

| Evento | Ação CRM |
|--------|----------|
| delivered | Logar activity type="email_sent" |
| opened | score_engagement += 5 |
| clicked | score_engagement += 15 |
| bounced | cadence_status → "bounced" |
| complained | cadence_status → "unsubscribed" |

### STEP 2: Polling Google Sheets (DMs)

```bash
curl -s "${SHEETS_BASE}/DM_Queue!A:H" -H "Authorization: Bearer ${GOOGLE_SHEETS_API_KEY}"
curl -s "${SHEETS_BASE}/Comment!A:E" -H "Authorization: Bearer ${GOOGLE_SHEETS_API_KEY}"
```

(`SHEETS_BASE` = `https://sheets.googleapis.com/v4/spreadsheets/${GOOGLE_SHEETS_ID}/values`)

DM done → logar activity. DM failed → logar erro.

### STEP 3: Classificar respostas com AI

| Classificação | Novo cadence_status |
|---------------|-------------------|
| interested | "replied" |
| not_interested | "unsubscribed" |
| maybe | manter "in_sequence" |
| out_of_office | "paused" (next_action_date +7d) |
| question | "replied" |

Na dúvida → "maybe".

### STEP 4: Atualizar CRM

```bash
# Score engagement
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/{contact_org_id}" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"score_engagement": <novo_score>}'
```

```bash
# Cadence status se mudou
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/cadence" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"cadence_status": "<novo_status>"}'
```

```bash
# Logar evento
curl -s -X POST "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/activities" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "<email_opened|email_sent|note>",
    "title": "<evento>",
    "metadata": {"module": "m6", "event": "<tipo>", "channel": "<email|dm>"}
  }'
```

### STEP 5: Relatório

```
====================================
M6 EVENT TRACKER — RELATÓRIO
====================================
📧 Emails: Delivered {n} | Opened {n} | Clicked {n} | Bounced {n}
💬 DMs: Done {n} | Failed {n}
🏷️ Replies: Interested {n} | Not interested {n} | Maybe {n}
====================================
```

Salve em `/tmp/m6_report_{YYYY-MM-DD_HHmm}.log`

## Regras
- Roda a cada 30min — só eventos NOVOS (marker em `/tmp/m6_last_run.txt`)
- NUNCA mudar "unsubscribed" ou "bounced" pra outro status
- Bounces = crítico, atualizar imediato
