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

### KOSMOS (criadores de conteúdo) — Instagram Only (Fire-and-Forget)
```
Step 1: Follow + Like (dia 0)        → Escreve em Follow + Like_Post
Step 2: Comentário no post (dia 2)   → Escreve em Comment
Step 3: DM Instagram (dia 5)         → Escreve em DM_Queue + Review_Queue
        ↓
        cadence_status = "awaiting_review"
        --- PAUSA: Humano verifica DM ---
        Se respondeu → replied
        Se não respondeu → in_sequence (continua)
        ↓
Step 4: DM Follow-up (dia 10)        → Escreve em DM_Queue → archived
```

**Modelo:** Fire-and-forget (CRM é fonte de verdade, não Axiom)
**Canal único:** Instagram (warmup antes da DM)
**Template:** `templates/instagram-sequence-kosmos.md`

**Dados para personalização (T15):**
- `source_detail.bio` → bio do Instagram
- `source_detail.recent_posts[]` → últimos 3 posts
- `source_detail.claude_analysis.sophistication_level` → tom da mensagem
- `source_detail.claude_analysis.product_detected` → produto/nicho
- `source_detail.claude_analysis.key_observations` → hooks

---

### OLIVEIRA-DEV (B2B / Advocacia-Tech) — Email Only
```
Step 1: Email frio (dia 0)           → M5a executa
Step 2: Email valor (dia 4)          → M5a executa
Step 3: Email ângulo diferente (dia 9) → M5a executa
Step 4: Email prova social (dia 14)  → M5a executa
Step 5: Email break-up (dia 21)      → M5a executa
```

**Canal único:** Email
**Template:** `templates/email-sequence-oliveira.md`

**Hierarquia de personalização (T15):**
1. `source_detail.google_maps.recent_reviews[]` → reviews (prioridade máxima)
2. `source_detail.instagram.recent_posts[]` → posts do IG do escritório
3. `source_detail.website_observations` → observações do site
4. `source_detail.team_size` → tamanho da equipe
5. Área de atuação + dor genérica (fallback)

**Dois serviços disponíveis:**
- **Sistema de Gestão:** prazos, organização, demandas
- **Portal de Acompanhamento:** cliente vê status, reduz ligações

**Seleção do serviço:**
- Review menciona "informada/transparência/acompanhamento" → Portal
- Review menciona "rápido/eficiente/organizado" → Gestão
- Equipe > 5 advogados → Gestão
- Área família/civil → Portal (volume de clientes)
- Área empresarial/tributário → Gestão (complexidade)

## Fluxo de entrada

### KOSMOS (Instagram) — Fire-and-Forget

| Condição | Ação |
|----------|------|
| `cadence_status` = "ready" + tenant = "kosmos" + tem instagram | Entra step 1 (Follow + Like_Post) |
| `cadence_status` = "in_sequence" + step 1 + 2 dias | Avança step 2 (Comment) |
| `cadence_status` = "in_sequence" + step 2 + 3 dias | Avança step 3 (DM_Queue) → `awaiting_review` |
| `cadence_status` = "awaiting_review" → humano marca `no_response` | Volta pra `in_sequence` |
| `cadence_status` = "in_sequence" + step 3 + 5 dias | Avança step 4 (DM follow-up) → `archived` |

**Status `awaiting_review`:**
- Após enviar DM (step 3), status muda para `awaiting_review`
- Humano verifica DM no Instagram e preenche Review_Queue
- Se `replied` → fim
- Se `no_response` → volta para `in_sequence`, permite step 4

### OLIVEIRA-DEV (Email)

| Condição | Ação |
|----------|------|
| `cadence_status` = "ready" + tenant = "oliveira-dev" + tem email | Entra step 1 (email cold) |
| `cadence_status` = "in_sequence" + step 1 + 4 dias | Avança step 2 (email valor) |
| `cadence_status` = "in_sequence" + step 2 + 5 dias | Avança step 3 (email ângulo) |
| `cadence_status` = "in_sequence" + step 3 + 5 dias | Avança step 4 (email case) |
| `cadence_status` = "in_sequence" + step 4 + 7 dias | Avança step 5 (email breakup) |
| `cadence_status` = "in_sequence" + step 5 enviado | Cadência completa → archived |

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

# Leads já em sequência (pra avançar steps)
curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=in_sequence&per_page=50" \
  -H "Authorization: Bearer ${CRM_API_KEY}"
```

**IMPORTANTE:** Não buscar mais `queued` — modelo fire-and-forget não usa status de fila.

Filtrar: `do_not_contact` != true

---

## Estrutura das Planilhas (Fire-and-Forget)

**Princípio:** Sheets são filas de trabalho para o Axiom consumir. Sem colunas de status.

### KOSMOS

| Aba | Colunas |
|-----|---------|
| `Follow` | A: username |
| `Like_Post` | A: username, B: post_url |
| `Comment` | A: username, B: post_url, C: comment_text |
| `DM_Queue` | A: username, B: message |
| `Review_Queue` | A: username, B: contact_org_id, C: dm_sent_at, D: review_status |

**Review_Queue:** Interface para verificação manual
- M4 popula quando envia DM (step 3)
- Humano preenche `review_status`: `replied`, `not_interested`, ou `no_response`
- Script `sync-review.sh` lê e atualiza CRM

### OLIVEIRA-DEV

| Aba | Colunas |
|-----|---------|
| `Email_Queue` | A: email, B: subject, C: html_body, D: step, E: contact_org_id, F: tenant, G: created_at |

**Nota:** Email mantém estrutura anterior (M5a processa)

### STEP 2: Decidir próximo step

**Lead entrando (cadence_status = "ready"):**

```
SE tenant == "kosmos":
  - Verificar: tem instagram?
  - SIM → Entra step 1 (Follow + Like_Post)
  - NÃO → Skip (não pode processar sem IG)

SE tenant == "oliveira-dev":
  - Verificar: tem email?
  - SIM → Entra step 1 (email cold)
  - NÃO → Skip (não pode processar sem email)
```

**Lead em sequência (cadence_status = "in_sequence"):**

```
# KOSMOS: delays em dias
DELAYS_KOSMOS = {1: 0, 2: 2, 3: 5, 4: 10}

# OLIVEIRA-DEV: delays em dias
DELAYS_OLIVEIRA = {1: 0, 2: 4, 3: 9, 4: 14, 5: 21}

dias_desde = (agora - last_action_at).days
proximo_step = cadence_step + 1

SE tenant == "kosmos":
  max_step = 4
  delays = DELAYS_KOSMOS

  # Step 3 → awaiting_review (precisa verificação manual)
  SE cadence_step == 3:
    # Só avança se status voltou pra in_sequence (humano marcou no_response)
    SKIP (aguardando review)

SE tenant == "oliveira-dev":
  max_step = 5
  delays = DELAYS_OLIVEIRA

SE proximo_step > max_step:
  → cadence_status = "archived" (fim)

SE dias_desde < delays[proximo_step] - delays[cadence_step]:
  → SKIP (ainda não é hora)

→ Avançar para proximo_step
```

**Status especial `awaiting_review` (KOSMOS):**
- Após step 3 (DM), status muda para `awaiting_review`
- M4 NÃO processa leads com esse status
- Humano verifica e preenche Review_Queue
- Script `sync-review.sh` atualiza CRM:
  - Se `replied` → cadence_status = "replied"
  - Se `no_response` → cadence_status = "in_sequence" (permite step 4)

**Lead em sequência (cadence_status = "in_sequence"):**

```
SE tenant == "kosmos":
  delays = [0, 2, 5]  # step 1, 2, 3
  max_step = 3

SE tenant == "oliveira-dev":
  delays = [0, 4, 9, 14, 21]  # steps 1-5
  max_step = 5

dias_desde = (now - last_contacted).days
proximo_step = cadence_step + 1

SE dias_desde >= delays[proximo_step]:
  SE proximo_step > max_step → cadência completa → archived
  SENÃO → avançar pro step
```

**Verificações antes de avançar:**
- Se lead respondeu (`cadence_status` = "replied") → STOP
- Se bounce → STOP
- Se unsubscribed → STOP
- Se not_interested → STOP

### STEP 3: Gerar mensagem personalizada com AI

Para cada lead, buscar dados completos incluindo source_detail:
```bash
curl -s -X GET "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}" \
  -H "Authorization: Bearer ${CRM_API_KEY}"
```

**KOSMOS — Extrair de `source_detail`:**
- `bio` (bio do Instagram)
- `recent_posts[]` (últimos 3 posts)
- `claude_analysis.sophistication_level` (1-10, ajusta tom)
- `claude_analysis.product_detected` (nicho/produto)
- `claude_analysis.key_observations` (hooks)

**OLIVEIRA-DEV — Extrair de `source_detail`:**
- `google_maps.recent_reviews[]` (reviews, prioridade 1)
- `instagram.recent_posts[]` (posts do IG do escritório)
- `website_observations` (dados do site)
- `team_size` (tamanho da equipe)
- `areas[]` (áreas de atuação)
- `full_name` (nome do decisor)

---

## Templates de Copy

**IMPORTANTE:** Use os templates de geração em `./templates/` para gerar copy personalizada.

### KOSMOS (Instagram)

| Step | Canal | Template | Max | Status após |
|------|-------|----------|-----|-------------|
| 1 | Follow+Like | N/A (escreve em Follow + Like_Post) | - | in_sequence |
| 2 | Comentário | `templates/comment-warmup.md` | 50 chars | in_sequence |
| 3 | DM | `templates/dm-opener.md` | 200 chars | **awaiting_review** |
| 4 | DM Follow-up | `templates/dm-followup.md` | 200 chars | archived |

**Template unificado:** `templates/instagram-sequence-kosmos.md`

**Nota sobre step 3 → 4:**
- Step 3 muda status para `awaiting_review` (pausa automação)
- Humano verifica DM e preenche Review_Queue
- Se `no_response` → script muda para `in_sequence` → M4 processa step 4

### OLIVEIRA-DEV (Email)

| Step | Canal | Template | Max |
|------|-------|----------|-----|
| 1 | Email cold | `templates/email-sequence-oliveira.md` | 80 palavras |
| 2 | Email valor | `templates/email-sequence-oliveira.md` | 80 palavras |
| 3 | Email ângulo | `templates/email-sequence-oliveira.md` | 80 palavras |
| 4 | Email case | `templates/email-sequence-oliveira.md` | 80 palavras |
| 5 | Email breakup | `templates/email-sequence-oliveira.md` | 50 palavras |

**Template unificado:** `templates/email-sequence-oliveira.md` (com lógica por step)

Cada template contém:
- Prompt de geração estruturado com lógica por step
- Hierarquia de personalização
- Banco de dores e serviços
- Anti-patterns a evitar
- Matriz de ângulos (OLIVEIRA-DEV)

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

**PROIBIDO em qualquer mensagem:**
- Erros gramaticais ou de digitação
- Tom amador ou informal demais
- Emojis excessivos (max 1 por mensagem DM, zero em email)
- Links quebrados ou genéricos
- Falta de personalização (nome, referência a conteúdo)
- "Olá, tudo bem?" e outras aberturas genéricas
- "posso te ajudar?", "vim oferecer", "temos uma solução"
- Pressão ou urgência artificial ("última chance", etc.)
- Audio ou mensagem copiada

**OBRIGATÓRIO:**
- Revisar copy antes de enfileirar (ortografia, tom, personalização)
- **Referencia obrigatoria a pelo menos 1 conteudo REAL do lead** (post, produto, bio)
- Tom profissional mas humano
- CTA claro e não agressivo
- Assinatura consistente

**Checklist antes de enfileirar cada mensagem:**
```
[ ] Nome do lead correto?
[ ] Referência específica (não genérica)?
[ ] Sem erros de português?
[ ] Tom adequado ao tenant?
[ ] CTA presente e não vendedor?
```

**Ajustar por tenant:**
- KOSMOS: casual, criador pra criador
- OLIVEIRA-DEV: profissional mas humano, sem "venho por meio desta", focar em dores do setor jurídico

---

### TEMPLATES OLIVEIRA-DEV (B2B / Escritórios de Advocacia)

**Ver template completo:** `templates/email-sequence-oliveira.md`

O template unificado contém:
- Lógica por step (1-5) com objetivos diferentes
- Hierarquia de personalização (review > post > site > equipe > área)
- Dois serviços: Sistema de Gestão vs Portal de Acompanhamento
- Matriz de ângulos para evitar repetição entre emails
- Banco de dores e gatilhos
- Exemplos completos por step

**REGRAS ESPECÍFICAS OLIVEIRA-DEV:**
- SEMPRE usar nome do decisor (não "Prezados" genérico)
- SEMPRE usar observação específica (review, post, site, equipe)
- TOM: profissional, mas humano — evitar "venho por meio desta"
- Focar em DOR específica detectada (prazo, atendimento, tempo do sócio)
- NÃO mencionar preço no primeiro contato
- Subject curto e direto (max 5 palavras, específico)
- Max 80 palavras por email (50 no breakup)
- Assinatura: "Vinicius Oliveira"

### STEP 4: Enfileirar e atualizar cadência (Fire-and-Forget)

**Modelo:** Escreve no Sheets e atualiza CRM imediatamente. Não espera confirmação do Axiom.

#### 4.1 — KOSMOS: Enfileirar por Step

**Step 1 — Follow + Like:**
```bash
# Escrever em Follow (A: username)
curl -s -X POST "${SHEETS_BASE}/Follow!A:A:append?valueInputOption=RAW" \
  -H "Authorization: Bearer ${SHEETS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"values": [["<username>"]]}'

# Escrever em Like_Post (A: username, B: post_url)
# post_url vem de source_detail.recent_posts[0].url
curl -s -X POST "${SHEETS_BASE}/Like_Post!A:B:append?valueInputOption=RAW" \
  -H "Authorization: Bearer ${SHEETS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"values": [["<username>", "<post_url>"]]}'
```

**Step 2 — Comment:**
```bash
# Escrever em Comment (A: username, B: post_url, C: comment_text)
curl -s -X POST "${SHEETS_BASE}/Comment!A:C:append?valueInputOption=RAW" \
  -H "Authorization: Bearer ${SHEETS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"values": [["<username>", "<post_url>", "<comment_text>"]]}'
```

**Step 3 — DM + Review_Queue:**
```bash
# Escrever em DM_Queue (A: username, B: message)
curl -s -X POST "${SHEETS_BASE}/DM_Queue!A:B:append?valueInputOption=RAW" \
  -H "Authorization: Bearer ${SHEETS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"values": [["<username>", "<message>"]]}'

# Escrever em Review_Queue (A: username, B: contact_org_id, C: dm_sent_at, D: review_status)
# review_status fica VAZIO — humano preenche depois
curl -s -X POST "${SHEETS_BASE}/Review_Queue!A:D:append?valueInputOption=RAW" \
  -H "Authorization: Bearer ${SHEETS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"values": [["<username>", "<contact_org_id>", "<timestamp>", ""]]}'
```

**Step 4 — DM Follow-up:**
```bash
# Escrever em DM_Queue (A: username, B: message)
curl -s -X POST "${SHEETS_BASE}/DM_Queue!A:B:append?valueInputOption=RAW" \
  -H "Authorization: Bearer ${SHEETS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"values": [["<username>", "<follow_up_message>"]]}'
```

#### 4.2 — OLIVEIRA-DEV: Enfileirar Email

```bash
# Escrever em Email_Queue (mantém estrutura original para M5a)
curl -s -X POST "${SHEETS_BASE}/Email_Queue!A:G:append?valueInputOption=RAW" \
  -H "Authorization: Bearer ${SHEETS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"values": [["<email>", "<subject>", "<html_body>", "<step>", "<contact_org_id>", "<tenant>", "<timestamp>"]]}'
```

#### 4.3 — Atualizar CRM (imediatamente)

```bash
# KOSMOS: status depende do step
SE step == 3:
  cadence_status = "awaiting_review"
SE step == 4:
  cadence_status = "archived"
SENÃO:
  cadence_status = "in_sequence"

# OLIVEIRA-DEV: sempre in_sequence até step 5
SE step == 5:
  cadence_status = "archived"
SENÃO:
  cadence_status = "in_sequence"

curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/cadence" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "cadence_status": "<status>",
    "cadence_step": <novo_step>,
    "last_action_at": "<timestamp>"
  }'
```

**NOTA:** Não usar mais status `queued`. Fire-and-forget assume que Axiom vai executar.

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
