# M4 — CADENCE ORCHESTRATOR

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.


## Contexto
Você é o módulo M4 do Motor de Outbound da KOSMOS / Oliveira Dev. Sua função é orquestrar a cadência multi-channel para leads prontos. Você decide o próximo step (email, DM), gera mensagem personalizada, e enfileira pra envio.

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
| `GET /v1/contacts?cadence_status=ready&per_page=50` | Leads prontos pra entrar |
| `GET /v1/contacts?cadence_status=in_sequence&per_page=50` | Leads pra avançar step |
| `GET /v1/contacts/:id` | Detalhes do lead |
| `PATCH /v1/contacts/:id` | Atualizar dados gerais |
| `PATCH /v1/contacts/:id/cadence` | Atualizar cadence_status e cadence_step |
| `POST /v1/contacts/:id/activities` | Logar ações |

Filtros GET: `cadence_status`, `classificacao`, `tenant`, `per_page`, `page`

## Sequências de Cadência

### KOSMOS (criadores de conteúdo)
```
Step 1: Email frio (dia 0)
Step 2: DM Instagram (dia 2)
Step 3: Email follow-up (dia 5)
Step 4: DM follow-up (dia 8)
Step 5: Email break-up (dia 12)
```

### OLIVEIRA-DEV (B2B)
```
Step 1: Email frio (dia 0)
Step 2: DM Instagram (dia 2)
Step 3: Email follow-up (dia 5)
Step 4: DM follow-up (dia 8)
Step 5: Email break-up (dia 14)
```

**Nota sobre Axiom:** Se `axiom_status` = "nurture" (lead foi aquecido pelo M8), o lead PULA step 1 e começa direto na DM (step 2). O aquecimento social já criou contexto.

## Fluxo de entrada

| Condição | Ação |
|----------|------|
| `cadence_status` = "ready" + classificacao A/B + tem email | Entra step 1 (email) |
| `cadence_status` = "ready" + `axiom_status` = "nurture" | Entra step 2 (DM, pula email) |
| `cadence_status` = "ready" + sem email + tem instagram | Entra step 2 (DM) |
| `cadence_status` = "in_sequence" + delay atingido | Avança pro próximo step |

## Instruções — Execute na ordem

### STEP 0: Obter access_token do Google Sheets

**OBRIGATÓRIO antes de qualquer escrita no Sheets.**

```bash
SHEETS_TOKEN=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=${GOOGLE_OAUTH_CLIENT_ID}" \
  -d "client_secret=${GOOGLE_OAUTH_CLIENT_SECRET}" \
  -d "refresh_token=${GOOGLE_OAUTH_REFRESH_TOKEN}" \
  -d "grant_type=refresh_token" | jq -r '.access_token')
```

`SHEETS_BASE` = `https://sheets.googleapis.com/v4/spreadsheets/${GOOGLE_SHEETS_ID}/values`

### STEP 1: Buscar leads prontos

```bash
# Leads pra entrar na cadência
curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=ready&classificacao=A&per_page=50" \
  -H "Authorization: Bearer ${CRM_API_KEY}"

curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=ready&classificacao=B&per_page=50" \
  -H "Authorization: Bearer ${CRM_API_KEY}"

# Leads já em sequência
curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=in_sequence&per_page=50" \
  -H "Authorization: Bearer ${CRM_API_KEY}"
```

Filtrar: `do_not_contact` != true

### STEP 2: Decidir próximo step

**Lead entrando (cadence_status = "ready"):**
- Checar tenant → selecionar sequência correta
- Checar axiom_status → se "nurture", pular pra step 2 (DM)
- Checar se tem email → se não, ir direto pra DM
- Setar step inicial

**Lead em sequência (cadence_status = "in_sequence"):**
- Ler `cadence_step` atual e `last_contacted`
- Calcular dias desde `last_contacted`
- Se dias >= delay do próximo step → avançar
- Se último step → cadência completa

**Verificações antes de avançar:**
- Se lead respondeu (check campo `cadence_status` mudou pra "replied" pelo M6) → STOP
- Se bounce → STOP
- Se unsubscribed → STOP

### STEP 3: Gerar mensagem personalizada com AI

Para cada lead, buscar dados completos do CRM:

```bash
curl -s -X GET "${CRM_BASE_URL}/v1/contacts/{contact_org_id}" \
  -H "Authorization: Bearer ${CRM_API_KEY}"
```

Ler o campo `source_detail` do lead.

---

**SE source_detail contém `recent_posts` E `gemini_analysis` (lead enriquecido pelo T15):**

Usar TODOS os dados disponíveis pra gerar copy genuinamente personalizada:

- `source_detail.recent_posts` → legendas dos posts reais (referência obrigatória a pelo menos 1)
- `source_detail.gemini_analysis.product_detected` → menção ao produto/nicho do lead
- `source_detail.gemini_analysis.content_style` → ajustar tom da mensagem
- `source_detail.gemini_analysis.sophistication_level` → linguagem:
  * 7-10: técnica, referências de mercado, jargão do nicho
  * 1-4: didática, mais explicativa, linguagem simples
  * 5-6: intermediária
- `source_detail.gemini_analysis.key_observations` → hook da mensagem
- `source_detail.gemini_analysis.text_in_images` → possível referência a conteúdo visual
- `source_detail.link_bio_type` → contexto sobre presença digital

Abordagem por classificação:
- **Classe A** (score >= 60): tom peer-to-peer, reconhecer expertise, CTA visita perfil ou lead magnet
- **Classe B** (score 30-59): tom consultivo, oferecer valor, CTA call

Regras da Seção 14 (OBRIGATÓRIO):
- NUNCA: áudio, mensagem copiada, emojis excessivos, "posso te ajudar?"
- Tom casual, peer-to-peer, como se já acompanhasse o trabalho
- A DM DEVE conter pelo menos 1 referência específica ao conteúdo real do lead
- Ajuste por tenant:
  * KOSMOS: casual, criador pra criador, como colega de mercado
  * Oliveira-dev: profissional, mas acessível, focado em resultado

---

**SE source_detail NÃO contém `recent_posts` (lead sem enrichment T15 — fallback):**

Gerar com dados disponíveis (bio, followers — comportamento anterior):

---

**Para TODOS os leads (com ou sem enrichment):**

Email frio (step 1):
- Subject curto e curioso
- Body max 100 palavras
- Tom casual (KOSMOS) ou profissional (oliveira-dev)
- Sem parecer vendedor

DM (step 2):
- Max 300 caracteres
- Casual, como seguidor que admira o trabalho
- Abrir conversa, não vender
- Sem link

Follow-ups (steps 3-4):
- Referenciar mensagem anterior
- Adicionar valor (insight, observação)
- Max 80 palavras

Break-up (step 5):
- Respeitoso, sem pressão
- "Porta aberta"
- Max 50 palavras

### STEP 4: Atualizar cadência e enfileirar

Para cada lead com envio decidido:

```bash
# Atualizar cadência
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/cadence" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "cadence_status": "queued",
    "cadence_step": <novo_step>
  }'
```

```bash
# Se canal = email → escrever na aba Email_Queue do Sheets
curl -s -X POST "${SHEETS_BASE}/Email_Queue!A:I:append?valueInputOption=RAW" \
  -H "Authorization: Bearer ${SHEETS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"values": [["<email>", "<subject>", "<html_body>", "pending", "<step>", "<contact_org_id>", "<tenant>", "<timestamp>", ""]]}'
```

```bash
# Se canal = axiom_dm → escrever na aba DM_Queue do Sheets
curl -s -X POST "${SHEETS_BASE}/DM_Queue!A:H:append?valueInputOption=RAW" \
  -H "Authorization: Bearer ${SHEETS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"values": [["<username>", "<message>", "pending", "<step>", "<contact_org_id>", "<tenant>", "<timestamp>", ""]]}'
```

**IMPORTANTE:** O CRM não suporta custom_fields. A fila de envio é pelo Google Sheets:
- M5a lê `Email_Queue` (status = "pending") → envia → marca "sent"
- M5b lê `DM_Queue` (status = "pending") → envia → marca "sent"

### STEP 5: Logar atividade

```bash
curl -s -X POST "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/activities" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "note",
    "title": "Cadência Step <N> — <channel> agendado",
    "metadata": {"module": "m4", "step": <N>, "channel": "<email|axiom_dm>"}
  }'
```

### STEP 6: Relatório

```
====================================
M4 CADENCE ORCHESTRATOR — RELATÓRIO
====================================
Data/hora: {timestamp}

📥 Entrando na cadência: {N}
  - Via email frio: {N}
  - Via DM (pós-Axiom): {N}
📤 Envios queued: {N}
  - Email: {N}
  - DM: {N}
⏭️ Skipped (delay): {N}
✅ Cadências completadas: {N}
Erros: {N}
====================================
```

Salve em `/tmp/m4_report_{YYYY-MM-DD}.log`

## Regras
- NUNCA 2 mensagens no mesmo dia pro mesmo lead
- NUNCA processar do_not_contact = true
- Respeitar delays rigorosamente
- Leads A prioridade sobre B
- MAX 50 leads por execução
- Se sem dados pro canal do step (sem IG pra DM), pular step
- Horários: emails 9h-18h, DMs 19h-21h (Brasília)
