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

### ADVOCACIA-TECH (Escritórios de Advocacia)
```
Step 1: Email frio para decisor (dia 0)
Step 2: DM Instagram do escritório (dia 3)
Step 3: Email follow-up (dia 7)
Step 4: DM follow-up (dia 10)
Step 5: Email break-up (dia 16)
```

**Dados extras para personalização (advocacia-tech):**
- `source_detail.decision_maker.name` → nome do decisor
- `source_detail.decision_maker.title` → cargo
- `source_detail.practice_areas[]` → áreas de atuação
- `source_detail.website_analysis.digital_maturity_score` → maturidade digital
- `source_detail.google_maps.rating` → reputação
- `source_detail.instagram.handle` → IG do escritório

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

# Leads queued (possíveis órfãos - queued mas não estão na fila do Sheets)
curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=queued&per_page=50" \
  -H "Authorization: Bearer ${CRM_API_KEY}"
```

**Tratamento de leads queued (órfãos):**
- Buscar Email_Queue e DM_Queue atual
- Se lead está `queued` no CRM mas NÃO existe na fila com status="pending" → recriar entrada na fila
- Isso recupera leads que ficaram presos por falha de rede/timeout

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

Para cada lead, buscar dados completos incluindo source_detail:
```bash
curl -s -X GET "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}" \
  -H "Authorization: Bearer ${CRM_API_KEY}"
```

Extrair de `source_detail`:
- `bio` (bio do Instagram)
- `recent_posts` (array com 3 posts recentes - se existir)
- `claude_analysis` (analise do T15 - se existir)

---

## Templates de Copy

**IMPORTANTE:** Use os templates de geração em `./templates/` para gerar copy personalizada.

| Step | Canal | Template | Max |
|------|-------|----------|-----|
| 1 | Email | `templates/email-cold.md` | 100 palavras |
| 2 | DM | `templates/dm-opener.md` | 50 palavras (300 chars) |
| 3 | Email | `templates/email-followup.md` | 80 palavras |
| 4 | DM | `templates/dm-followup.md` | 50 palavras |
| 5 | Email | `templates/email-breakup.md` | 50 palavras |

Cada template contém:
- Prompt de geração estruturado
- Exemplos por tenant (KOSMOS vs Oliveira-dev)
- Anti-patterns a evitar
- Ajustes por sophistication_level e classificação

---

### Dados do Lead para Personalização

**SE lead tem `recent_posts` e `claude_analysis` (enriquecido pelo T15):**

Usar TODOS os dados pra gerar copy genuinamente personalizada:

- **Legendas dos posts** → referencia real ao conteudo do lead
- **claude_analysis.product_detected** → mencionar produto/nicho especifico
- **claude_analysis.content_style** → ajustar abordagem (educational = dicas, sales = direto)
- **claude_analysis.sophistication_level** → ajustar linguagem:
  - 7-10: tom tecnico, peer-to-peer, reconhecer expertise
  - 4-6: tom consultivo, oferecer valor
  - 1-3: tom didatico, explicar beneficios
- **claude_analysis.key_observations** → usar como hook da mensagem

**SE lead NAO tem `recent_posts` (fallback):**
- Usar dados da bio + followers
- Seguir mesmo template, mas com menos personalização

### Abordagem por Classificação

| Classe | Score | Tom | CTA |
|--------|-------|-----|-----|
| A | >= 60 | Peer-to-peer, reconhecer expertise | CTA leve |
| B | 30-59 | Consultivo, oferecer valor | CTA call |

### Regras Obrigatórias de Copy

- NUNCA: audio, mensagem copiada, emojis excessivos, "posso te ajudar?"
- Tom casual, peer-to-peer, como se ja acompanhasse o trabalho
- **Referencia obrigatoria a pelo menos 1 conteudo REAL do lead** (post, produto, visual)
- Ajustar por tenant:
  * KOSMOS: casual, criador pra criador
  * Oliveira-dev: profissional, mas acessivel

---

### TEMPLATES ADVOCACIA-TECH (Escritórios de Advocacia)

**Tom geral:** Profissional mas acessível. Mostrar conhecimento do setor jurídico. Focar em dores reais: gestão de processos, tempo com burocracia, atendimento ao cliente.

**STEP 1 — Email frio para decisor:**

```
Assunto: [Área de atuação] + tecnologia — uma combinação que funciona

[Nome do decisor],

Vi que o [Nome do escritório] atua com [área de prática]. Tenho trabalhado com escritórios de perfil parecido em projetos de [automação/portal do cliente/gestão].

A maioria dos sócios que converso menciona o tempo gasto em tarefas operacionais — controle de prazos, atualização de clientes, emissão de documentos.

Seria interessante trocar uma ideia sobre como outros escritórios estão usando tech pra liberar tempo dos advogados?

Vinícius Oliveira
```

**Variações por área de prática:**

| Área | Gancho |
|------|--------|
| Empresarial/M&A | "due diligence automatizada", "gestão de documentos" |
| Tributário | "controle de prazos fiscais", "dashboard de processos" |
| Trabalhista | "volume de reclamações", "automação de cálculos" |
| Digital/Tech | "natural fit com inovação", "clientes esperam tech" |
| Civil | "gestão de contratos", "portal do cliente" |

**STEP 2 — DM Instagram do escritório:**

```
Oi! Vi o trabalho do escritório com [área]. Tenho ajudado escritórios similares a otimizar a gestão com tech. Vocês usam algum sistema específico hoje?
```

**Variações:**
- "Vi que atuam forte em [área]. Como está a gestão de processos aí?"
- "Acompanho o trabalho de vocês. Já pensaram em um portal pro cliente acompanhar os casos?"

**STEP 3 — Email follow-up:**

```
Assunto: Re: [assunto anterior]

[Nome],

Voltando ao contato anterior — recentemente ajudei o [tipo de escritório similar] a reduzir 40% do tempo gasto em atualização de clientes com um portal simples.

Se fizer sentido pro [Nome do escritório], posso mostrar como funcionaria na prática.

Vinícius
```

**STEP 4 — DM follow-up:**

```
[Nome], enviei um email sobre automação pra escritórios. Chegou a ver? Se quiser, podemos marcar 15min pra eu mostrar cases similares.
```

**STEP 5 — Email break-up:**

```
Assunto: Última tentativa

[Nome],

Entendo que agenda de sócio é corrida. Não quero ser insistente.

Se em algum momento fizer sentido otimizar a operação do escritório com tecnologia, estou por aqui.

Sucesso,
Vinícius
```

**REGRAS ESPECÍFICAS ADVOCACIA-TECH:**
- SEMPRE usar nome do decisor (não "Prezados" genérico)
- SEMPRE mencionar área de atuação específica
- TOM: profissional, mas humano — evitar "venho por meio desta"
- Focar em DOR: tempo, burocracia, atendimento ao cliente
- NÃO mencionar preço no primeiro contato
- Subject curto e direto (evitar "Proposta Comercial")

### STEP 4: Enfileirar e atualizar cadência

**ORDEM CRÍTICA:** Primeiro escreve no Sheets, depois atualiza CRM. Se Sheets falhar, lead fica "ready" e será retentado.

Para cada lead com envio decidido:

**4.1 — Verificar duplicata (OBRIGATÓRIO):**

```bash
# Buscar fila atual pra checar se lead já está pendente
QUEUE_DATA=$(curl -s "${SHEETS_BASE}/Email_Queue!A:I?key=${GOOGLE_SHEETS_API_KEY}")

# Verificar se contact_org_id já existe com status=pending (coluna F = contact_org_id, coluna D = status)
# Se encontrar → SKIP este lead (já está na fila)
```

Se lead já está na fila com `status=pending` → **NÃO adicionar novamente**, pular pro próximo lead.

**4.2 — Escrever na fila (Sheets PRIMEIRO):**

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

**4.3 — Atualizar CRM (só se Sheets sucesso):**

```bash
# Só executar se o append no Sheets retornou sucesso (HTTP 200)
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/cadence" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "cadence_status": "queued",
    "cadence_step": <novo_step>
  }'
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
